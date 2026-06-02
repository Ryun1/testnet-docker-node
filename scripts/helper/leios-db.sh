#!/bin/bash
# Shared Leios database side-loading logic.
#
# Sourced by start-node.sh (initial side-load) and refresh-leios-db.sh
# (crash recovery). Defines the relay list and download_leios_db() only —
# no top-level side effects, and it deliberately does NOT set `script_dir`
# so it can be sourced after cardano-cli-wrapper.sh without clobbering it.

# Colors are used by the messages below; default them so this helper works
# whether or not the caller already defined them.
: "${GREEN:=\033[0;32m}"
: "${YELLOW:=\033[0;33m}"
: "${CYAN:=\033[0;36m}"
: "${NC:=\033[0m}"

# Relay endpoints that serve a side-loadable leios.db snapshot (the SQLite
# database plus its write-ahead log). Tried in order until one succeeds.
leios_db_relays=(
  "https://leios1-rel-a-1.play.dev.cardano.org"
  "https://leios2-rel-b-1.play.dev.cardano.org"
  "https://leios3-rel-c-1.play.dev.cardano.org"
)

# Marker file (kept next to leios.db, in the bind-mounted /leios volume) whose
# mtime records the last refresh ATTEMPT. The container entrypoint uses it to
# throttle re-downloads so a crash loop doesn't re-pull ~190MB on every restart.
# The node never touches it, so it's a reliable signal (unlike leios.db's mtime,
# which the running node bumps constantly).
leios_db_refresh_marker=".leios-db-refreshed"

# True (0) if leios.db was refresh-attempted within the last $2 seconds.
#   leios_db_recently_refreshed <dest_dir> <interval_seconds>
leios_db_recently_refreshed() {
  local dest_dir=$1 interval=$2
  local marker="$dest_dir/$leios_db_refresh_marker"
  [ -f "$marker" ] || return 1
  local now mtime
  now=$(date +%s)
  # GNU stat (Linux container) first, BSD stat (macOS host) as fallback.
  mtime=$(stat -c %Y "$marker" 2>/dev/null || stat -f %m "$marker" 2>/dev/null) || return 1
  [ $(( now - mtime )) -lt "$interval" ]
}

# Side-load the Leios SQLite database from the first reachable relay into $1
# (the host dir bind-mounted to /leios, which is the node's working directory).
# The node opens this database read-write, so the files are given rw permissions.
# Any stale -shm is removed so SQLite rebuilds it from the downloaded -wal. A
# total failure is non-fatal: the node starts with an empty leios database.
download_leios_db() {
  local dest_dir=$1
  mkdir -p "$dest_dir"
  rm -f "$dest_dir"/leios.db "$dest_dir"/leios.db-wal "$dest_dir"/leios.db-shm

  local relay
  for relay in "${leios_db_relays[@]}"; do
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
      # Stamp the refresh marker so the entrypoint can throttle re-downloads.
      touch "$dest_dir/$leios_db_refresh_marker" 2>/dev/null || true
      echo -e "${GREEN}Side-loaded leios.db into ${dest_dir} (rw).${NC}"
      return 0
    fi
    echo -e "${YELLOW}Relay ${relay} unavailable, trying next...${NC}"
  done

  # Record the failed attempt too, so a crash loop with unreachable relays does
  # not retry the download on every single restart.
  touch "$dest_dir/$leios_db_refresh_marker" 2>/dev/null || true
  echo -e "${YELLOW}Warning: could not side-load leios.db from any relay.${NC}"
  echo -e "${YELLOW}The node will start with an empty leios database.${NC}"
  return 1
}
