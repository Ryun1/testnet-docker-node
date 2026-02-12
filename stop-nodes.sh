#!/bin/bash
set -euo pipefail

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# Get all running containers matching the node pattern
containers=$(docker ps --format "{{.Names}}" | grep -E "^node-[^-]+-[^-]+-container$" || true)

if [ -z "$containers" ]; then
  echo -e "${YELLOW}No Cardano node containers found running.${NC}"
  exit 0
fi

# Convert to array (compatible with Bash 3.x on macOS)
container_list=()
while IFS= read -r line; do
  container_list+=("$line")
done <<< "$containers"
count=${#container_list[@]}

# Non-interactive mode (CI or piped input): stop all containers automatically
if [ ! -t 0 ] && [ ! -t 1 ]; then
  echo "Stopping all Cardano node containers..."
  stop_list=("${container_list[@]}")
else
  # Interactive mode: let user choose
  echo -e "${CYAN}Running Cardano node containers:${NC}"
  for i in "${!container_list[@]}"; do
    echo -e "  ${GREEN}$((i + 1))${NC}) ${BLUE}${container_list[$i]}${NC}"
  done
  echo -e "  ${GREEN}$((count + 1))${NC}) ${RED}Stop all${NC}"
  echo

  echo -e "${CYAN}Select a container to stop (1-$((count + 1))):${NC}"
  read -r choice < /dev/tty

  # Validate input
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $((count + 1)) ]; then
    echo -e "${RED}Invalid selection.${NC}"
    exit 1
  fi

  # Build list of containers to stop
  if [ "$choice" -eq $((count + 1)) ]; then
    stop_list=("${container_list[@]}")
  else
    stop_list=("${container_list[$((choice - 1))]}")
  fi
fi

# Stop and remove selected containers
for container in "${stop_list[@]}"; do
  echo -e "${YELLOW}Stopping: $container${NC}"
  docker stop "$container" 2>/dev/null || true
  docker rm "$container" 2>/dev/null || true
  echo -e "${GREEN}Stopped: $container${NC}"
done

echo
echo -e "${GREEN}Done.${NC}"
