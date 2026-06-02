#!/bin/bash
#
# Container entrypoint + crash supervisor for the leiosnet node.
#
# Runs the node (passed as "$@") and watches for the upstream LeiosCert crash:
#   "cardano-node: ExceptionInLinkedThread ... Announced EB ... not available?LeiosCert"
# When it happens, ESCALATES recovery (rotate relays -> wipe & rebuild from
# chain; see recover_leios_db in leios-db.sh) and re-runs the node, repeating
# until the node stays up. Because the crash is handled in-process, the node
# self-heals without relying on the compose `restart: always` policy, which
# remains an outer safety net for other (non-LeiosCert) failures.
#
# Honest caveat: if no relay AND no peer has the missing endorsement block, this
# keeps cycling rather than fixing it — that's the upstream bug, not this loop.
#
# Design notes:
#  - Only stderr is captured (the LeiosCert message is printed there); the node's
#    voluminous JSON stdout logs pass straight through, so the capture file stays
#    tiny even on long healthy runs.
#  - SIGTERM/SIGINT are forwarded to the node so `docker stop` shuts SQLite down
#    cleanly and `leios.db` is not corrupted mid-write.

set -uo pipefail

leios_dir="${LEIOS_DB_DIR:-/leios}"
backoff="${LEIOS_RECOVERY_BACKOFF_SECONDS:-10}"

# shellcheck source=scripts/helper/leios-db.sh
source "${LEIOS_DB_LIB:-/usr/local/bin/leios-db.sh}"

child=""
terminating=0
on_term() {
  terminating=1
  [ -n "$child" ] && kill -TERM "$child" 2>/dev/null || true
}
trap on_term TERM INT

err_file="$(mktemp)"
trap 'rm -f "$err_file"' EXIT

# Wait for $child to actually exit, surviving waits interrupted by a trapped
# signal. Sets `rc` to the child's real exit status.
wait_for_child() {
  wait "$child"; rc=$?
  while kill -0 "$child" 2>/dev/null; do
    wait "$child"; rc=$?
  done
}

# Sleep that can be interrupted by SIGTERM/SIGINT (so a docker stop during the
# recovery backoff exits promptly instead of hanging).
interruptible_sleep() {
  sleep "$1" & child=$!
  wait "$child" 2>/dev/null || true
  child=""
}

attempt=0
while true; do
  : > "$err_file"

  # Run the node; capture stderr (where LeiosCert is printed) while still
  # echoing it to the container's stderr. stdout passes through untouched.
  "$@" 2> >(tee -a "$err_file" >&2) &
  child=$!
  wait_for_child
  child=""

  # Clean shutdown requested (docker stop) — propagate the node's exit code.
  if [ "$terminating" -eq 1 ]; then
    exit "$rc"
  fi

  # Node exited on its own.
  if [ "$rc" -eq 0 ]; then
    echo "Node exited cleanly (rc=0); supervisor stopping."
    exit 0
  fi

  if grep -qE "LeiosCert|Announced EB" "$err_file"; then
    attempt=$(( attempt + 1 ))
    echo -e "${YELLOW}Detected LeiosCert crash (rc=${rc}); recovery attempt ${attempt} in ${backoff}s...${NC}"
    interruptible_sleep "$backoff"
    [ "$terminating" -eq 1 ] && exit "$rc"
    recover_leios_db "$leios_dir" "$attempt"
    continue
  fi

  # Some other crash — don't mask it in a tight loop; let `restart: always`
  # (with Docker's own backoff) restart the container.
  echo -e "${YELLOW}Node crashed (rc=${rc}) without a LeiosCert signature; deferring to the restart policy.${NC}"
  interruptible_sleep 3
  exit "$rc"
done
