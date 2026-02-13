#!/bin/bash
set -euo pipefail

# Truncate the cardano-node database to a specific block number
# Requires node version 10.6.2+ (which includes the db-truncater tool)

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# Get the project root
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd "$script_dir/../.." && pwd)"

# Get running containers matching the node pattern
containers=$(docker ps --format "{{.Names}}" | grep -E "^node-[^-]+-[^-]+-container$" || true)

# Also check stopped containers
all_containers=$(docker ps -a --format "{{.Names}}" | grep -E "^node-[^-]+-[^-]+-container$" || true)

# Build a list of available node directories (which have a db)
node_dirs=()
while IFS= read -r dir; do
  [ -z "$dir" ] && continue
  dirname=$(basename "$dir")
  if [[ "$dirname" =~ ^node-(.+)-([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    node_dirs+=("$dirname")
  fi
done < <(find "$base_dir" -maxdepth 1 -type d -name "node-*" 2>/dev/null | sort)

if [ ${#node_dirs[@]} -eq 0 ]; then
  echo -e "${RED}Error: No node directories found.${NC}"
  exit 1
fi

# Let the user select which node to truncate
echo -e "${CYAN}Select a node to truncate:${NC}"
select node_dir in "${node_dirs[@]}"; do
  if [ -n "$node_dir" ]; then
    echo -e "${GREEN}Selected: $node_dir${NC}"
    break
  else
    echo -e "${RED}Invalid selection. Please try again.${NC}"
  fi
done

# Extract network and version from the directory name
if [[ "$node_dir" =~ ^node-(.+)-([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
  network="${BASH_REMATCH[1]}"
  node_version="${BASH_REMATCH[2]}"
else
  echo -e "${RED}Error: Could not parse network and version from $node_dir${NC}"
  exit 1
fi

container_name="node-${network}-${node_version}-container"
db_dir="$base_dir/$node_dir/db"
config_dir="$base_dir/$node_dir/config"

# Validate db directory exists
if [ ! -d "$db_dir" ]; then
  echo -e "${RED}Error: Database directory not found: $db_dir${NC}"
  exit 1
fi

# Validate config exists
if [ ! -f "$config_dir/config.json" ]; then
  echo -e "${RED}Error: Config file not found: $config_dir/config.json${NC}"
  exit 1
fi

# Get block number from user
echo
echo -e "${CYAN}Enter the block number to truncate after:${NC}"
read -r block_number

# Validate block number is numeric
if ! [[ "$block_number" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}Error: Block number must be a positive integer.${NC}"
  exit 1
fi

# Check if the container is running and stop it
is_running=$(docker ps --format "{{.Names}}" | grep -E "^${container_name}$" || true)
was_running=false

if [ -n "$is_running" ]; then
  was_running=true
  echo
  echo -e "${YELLOW}Stopping container $container_name...${NC}"
  docker stop "$container_name" > /dev/null
  echo -e "${GREEN}Container stopped.${NC}"
fi

# Run db-truncater in a temporary container with the same volumes
echo
echo -e "${CYAN}Running db-truncater (truncate after block $block_number)...${NC}"
docker run --rm \
  --platform linux/amd64 \
  --entrypoint "" \
  -v "$db_dir:/data/db" \
  -v "$config_dir:/config" \
  "ghcr.io/intersectmbo/cardano-node:${node_version}" \
  db-truncater \
    --db /data/db \
    --truncate-after-block "$block_number" \
    --config /config/config.json

# Clean up ledger, volatile, and clean directories
echo
echo -e "${CYAN}Cleaning up ledger, volatile, and clean directories...${NC}"
for subdir in ledger volatile clean; do
  if [ -d "$db_dir/$subdir" ]; then
    rm -rf "$db_dir/$subdir"
    echo -e "${YELLOW}Removed: $db_dir/$subdir${NC}"
  fi
done

echo
echo -e "${GREEN}Database truncated successfully.${NC}"

# Offer to restart if the container was running
if [ "$was_running" = true ]; then
  echo
  echo -e "${CYAN}The container was running before truncation. Restart it? (y/n):${NC}"
  read -r restart_choice
  if [ "$restart_choice" = "y" ] || [ "$restart_choice" = "Y" ]; then
    echo -e "${YELLOW}Starting container $container_name...${NC}"
    docker start "$container_name"
    echo -e "${GREEN}Container restarted.${NC}"
  else
    echo -e "${YELLOW}Container left stopped. Use ./start-node.sh to restart.${NC}"
  fi
fi
