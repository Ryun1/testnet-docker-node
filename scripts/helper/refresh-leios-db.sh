#!/bin/bash
#
# Recover a crashed Leios node by refreshing its side-loaded leios.db snapshot.
#
# The Leios node aborts with a "LeiosCert / Announced EB ... not available"
# exception when its local SQLite leios.db is missing an endorsement block that
# the chain references. The fix on this dev testnet is to re-download leios.db
# from a relay that has the block, then restart the node.
#
# This stops the leios container, re-side-loads leios.db (reusing the exact
# download logic from start-node.sh via scripts/helper/leios-db.sh), and brings
# the node back up non-interactively.

set -euo pipefail

# Resolve repo root BEFORE sourcing anything (sourced helpers may set their own
# script_dir; see scripts/helper/cardano-cli-wrapper.sh). This script lives in
# scripts/helper/, so the repo root is two levels up.
project_root="$(cd "$(dirname "$0")/../.." && pwd)"

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# The leios node is the only "*-leios-image" variant.
NODE_VERSION="leios-image"

# --- Locate the leios data dir ------------------------------------------------
# Glob node-<net>-leios-image/leios under the repo root (leiosnet -> the one match).
leios_dirs=()
for d in "$project_root"/node-*-leios-image/leios; do
  [ -d "$d" ] && leios_dirs+=("$d")
done

if [ "${#leios_dirs[@]}" -eq 0 ]; then
  echo -e "${RED}Error: no node-*-leios-image/leios directory found under $project_root.${NC}"
  echo -e "${YELLOW}Start a Leios node first with ./start-node.sh (select leios-image).${NC}"
  exit 1
elif [ "${#leios_dirs[@]}" -gt 1 ]; then
  echo -e "${RED}Error: multiple leios node directories found:${NC}"
  printf '  %s\n' "${leios_dirs[@]}"
  echo -e "${YELLOW}Refusing to guess which one to refresh.${NC}"
  exit 1
fi

leios_dir="${leios_dirs[0]}"
node_dir="$(dirname "$leios_dir")"            # .../node-<net>-leios-image
network_normalized="$(basename "$node_dir")"  # node-<net>-leios-image
network_normalized="${network_normalized#node-}"
network_normalized="${network_normalized%-leios-image}"
container_name="node-$network_normalized-$NODE_VERSION-container"

echo -e "${BLUE}Network:   ${NC}$network_normalized"
echo -e "${BLUE}Leios dir: ${NC}$leios_dir"
echo -e "${BLUE}Container: ${NC}$container_name"
echo ""

# --- Pick docker compose command ---------------------------------------------
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  compose_cmd="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  compose_cmd="docker-compose"
else
  echo -e "${RED}Error: Neither 'docker compose' nor 'docker-compose' is available${NC}"
  exit 1
fi

# --- Stop the leios container -------------------------------------------------
# The node runs inside Docker (network_mode: host), so a host-side pgrep would
# never see it — check/stop the container instead. Done before touching the DB
# so we never overwrite leios.db while the node holds it open.
if docker ps --format '{{.Names}}' | grep -qx "$container_name"; then
  echo -e "${YELLOW}Stopping running container: $container_name${NC}"
  docker stop "$container_name" >/dev/null 2>&1 || true
  docker rm "$container_name" >/dev/null 2>&1 || true
  echo -e "${GREEN}Stopped: $container_name${NC}"
elif docker ps -a --format '{{.Names}}' | grep -qx "$container_name"; then
  echo -e "${YELLOW}Removing stopped container: $container_name${NC}"
  docker rm "$container_name" >/dev/null 2>&1 || true
else
  echo -e "${GREEN}No running container named $container_name.${NC}"
fi
echo ""

# --- Refresh leios.db ---------------------------------------------------------
source "$project_root/scripts/helper/leios-db.sh"
download_leios_db "$leios_dir" || true
echo ""

# --- Restart the node ---------------------------------------------------------
# Minimal non-interactive bring-up mirroring start-node.sh's compose invocation.
compose_file="$project_root/docker-compose.leios-image.yml"

# Port assignment must match assign_port_for_version() in start-node.sh:
# non-numeric label -> base 3001 + (cksum % 100).
offset=$(( $(echo "$NODE_VERSION" | cksum | cut -d' ' -f1) % 100 ))
export NODE_PORT=$((3001 + offset))

export NETWORK="$network_normalized"
export NODE_VERSION
# Network magic, read from shelley-genesis like start-node.sh does.
export NETWORK_ID="$(jq -r '.networkMagic' "$node_dir/config/shelley-genesis.json")"

echo -e "${CYAN}Restarting the Leios node (port $NODE_PORT)...${NC}"
( cd "$project_root" && envsubst < "$compose_file" | $compose_cmd -f - up -d --build )

echo ""
echo -e "${GREEN}Done. Follow the node with:${NC}"
echo -e "  ${CYAN}docker logs -f $container_name${NC}"
