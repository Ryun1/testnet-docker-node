#!/bin/bash
#
# Container entrypoint for the leiosnet node (baked into Dockerfile.leios-image).
#
# Refreshes the side-loaded leios.db BEFORE the node opens it, then execs the
# node. Because this runs on every container start — including Docker's
# `restart: always` auto-restarts after a crash — the
#   "LeiosCert / Announced EB ... not available"
# crash self-heals (fresh db on restart) instead of crash-looping on a stale db.
#
# Re-downloads are throttled via LEIOS_DB_REFRESH_MIN_INTERVAL (seconds, default
# 600) so a rapid crash loop doesn't re-pull ~190MB on every restart attempt.

set -euo pipefail

leios_dir="${LEIOS_DB_DIR:-/leios}"
interval="${LEIOS_DB_REFRESH_MIN_INTERVAL:-600}"

# shellcheck source=scripts/helper/leios-db.sh
source /usr/local/bin/leios-db.sh

if leios_db_recently_refreshed "$leios_dir" "$interval"; then
  echo "leios.db was refresh-attempted within the last ${interval}s; skipping re-download."
else
  echo "Refreshing leios.db before starting the node..."
  download_leios_db "$leios_dir" || true
fi

# Hand off to the node command from docker-compose (passed as arguments).
exec "$@"
