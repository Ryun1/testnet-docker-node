#!/bin/bash
set -euo pipefail

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# Get all running containers started by this project
containers=$(docker ps --filter "label=managed-by=testnet-docker-node" --format "{{.Names}}" || true)

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

# Get the project root directory
script_dir=$(cd "$(dirname "$0")" && pwd)

# Stop and remove selected containers, and clean up host-side socat bridges
for container in "${stop_list[@]}"; do
  echo -e "${YELLOW}Stopping: $container${NC}"
  docker stop "$container" 2>/dev/null || true
  docker rm "$container" 2>/dev/null || true
  echo -e "${GREEN}Stopped: $container${NC}"

  # If this is a node container (not a socat sidecar), clean up the host-side socat bridge
  if [[ "$container" == node-*-container ]]; then
    # Derive node directory from container name: node-{network}-{version}-container -> node-{network}-{version}
    node_dir_name=$(echo "$container" | sed 's/-container$//')
    node_dir="$script_dir/$node_dir_name"

    # Kill host-side socat process if running
    if [ -f "$node_dir/socat.pid" ]; then
      socat_pid=$(cat "$node_dir/socat.pid" 2>/dev/null || true)
      if [ -n "$socat_pid" ] && kill -0 "$socat_pid" 2>/dev/null; then
        echo -e "${YELLOW}Stopping host-side socat bridge (PID $socat_pid)${NC}"
        kill "$socat_pid" 2>/dev/null || true
      fi
      rm -f "$node_dir/socat.pid"
    fi

    # Clean up the host socket file
    rm -f "$node_dir/node.socket"

    # Also stop the socat sidecar container if it wasn't already in the stop list
    socat_container="${node_dir_name}-socat"
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${socat_container}$"; then
      if ! printf '%s\n' "${stop_list[@]}" | grep -q "^${socat_container}$"; then
        echo -e "${YELLOW}Stopping socat sidecar: $socat_container${NC}"
        docker stop "$socat_container" 2>/dev/null || true
        docker rm "$socat_container" 2>/dev/null || true
        echo -e "${GREEN}Stopped: $socat_container${NC}"
      fi
    fi
  fi
done

echo
echo -e "${GREEN}Done.${NC}"
