#!/bin/bash
# Shared Leios database side-loading + crash-recovery logic.
#
# Sourced by:
#   - start-node.sh                       (initial host-side side-load)
#   - scripts/helper/refresh-leios-db.sh  (manual force-recovery)
#   - scripts/helper/leios-entrypoint.sh  (in-container crash supervisor)
#
# Defines vars/functions only — no top-level side effects — and deliberately
# does NOT set `script_dir` so it can be sourced after cardano-cli-wrapper.sh
# without clobbering it.

# Colors are used by the messages below; default them so this helper works
# whether or not the caller already defined them.
: "${GREEN:=\033[0;32m}"
: "${YELLOW:=\033[0;33m}"
: "${CYAN:=\033[0;36m}"
: "${NC:=\033[0m}"

# Relay endpoints that serve a side-loadable leios.db snapshot (the SQLite
# database plus its write-ahead log). Tried/rotated in order.
leios_db_relays=(
  "https://leios1-rel-a-1.play.dev.cardano.org"
  "https://leios2-rel-b-1.play.dev.cardano.org"
  "https://leios3-rel-c-1.play.dev.cardano.org"
)

# Wipe the local Leios database so the node starts clean. Used as the escalation
# fallback: with no usable snapshot the node rebuilds Leios state from the chain
# it already trusts (self-consistent and relay-independent).
wipe_leios_db() {
  local dest_dir=$1
  rm -f "$dest_dir"/leios.db "$dest_dir"/leios.db-wal "$dest_dir"/leios.db-shm
  echo -e "${YELLOW}Wiped leios.db in ${dest_dir}; the node will rebuild Leios state from the chain.${NC}"
}

# Side-load leios.db from ONE relay into $1. Removes stale leios.db* first, then
# fetches leios.db (+ best-effort -wal) and makes them rw for the node. Any stale
# -shm is removed so SQLite rebuilds it from the downloaded -wal.
#   download_leios_db_from <dest_dir> <relay_url>   -> 0 on success, 1 on failure
download_leios_db_from() {
  local dest_dir=$1 relay=$2
  mkdir -p "$dest_dir"
  rm -f "$dest_dir"/leios.db "$dest_dir"/leios.db-wal "$dest_dir"/leios.db-shm

  echo -e "${CYAN}Side-loading leios.db from ${relay} ...${NC}"
  if curl --silent --show-error --fail --location --max-time 600 \
       -o "$dest_dir/leios.db" "${relay}/leios.db"; then
    # The write-ahead log keeps the snapshot current; best-effort.
    curl --silent --fail --location --max-time 600 \
      -o "$dest_dir/leios.db-wal" "${relay}/leios.db-wal" \
      || rm -f "$dest_dir/leios.db-wal"
    # Make the database writable for the node (rw permissions).
    chmod 0664 "$dest_dir"/leios.db* 2>/dev/null || true
    chmod 0775 "$dest_dir" 2>/dev/null || true
    echo -e "${GREEN}Side-loaded leios.db into ${dest_dir} (rw).${NC}"
    return 0
  fi
  echo -e "${YELLOW}Relay ${relay} unavailable.${NC}"
  return 1
}

# Side-load leios.db from the first reachable relay (tried in order). A total
# failure is non-fatal: the node starts with an empty leios database and builds
# it from the chain. Used for the initial side-load (start-node.sh) and the
# manual refresh script.
download_leios_db() {
  local dest_dir=$1 relay
  for relay in "${leios_db_relays[@]}"; do
    if download_leios_db_from "$dest_dir" "$relay"; then
      return 0
    fi
    echo -e "${YELLOW}Trying next relay...${NC}"
  done
  echo -e "${YELLOW}Warning: could not side-load leios.db from any relay.${NC}"
  echo -e "${YELLOW}The node will start with an empty leios database.${NC}"
  return 1
}

# Escalating crash recovery, called once per LeiosCert crash with a 1-based
# attempt counter. Cycles relay0 -> relay1 -> ... -> wipe -> relay0 -> ... so it
# rotates relays (which may have caught up by the next loop) and never gets
# stuck; the wipe step falls back to rebuilding Leios state from the chain.
#   recover_leios_db <dest_dir> <attempt>
recover_leios_db() {
  local dest_dir=$1 attempt=$2
  local n_relays=${#leios_db_relays[@]}
  local cycle=$(( n_relays + 1 ))
  local idx=$(( (attempt - 1) % cycle ))
  if [ "$idx" -lt "$n_relays" ]; then
    echo -e "${CYAN}Recovery attempt ${attempt}: refreshing from relay $(( idx + 1 ))/${n_relays}.${NC}"
    download_leios_db_from "$dest_dir" "${leios_db_relays[$idx]}" || true
  else
    echo -e "${CYAN}Recovery attempt ${attempt}: wiping leios.db to rebuild from chain.${NC}"
    wipe_leios_db "$dest_dir"
  fi
}
