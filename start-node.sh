#!/bin/bash

# errors are handled gracefully to tell the user
# set -euo pipefail

# ----------------------------------------
ALLOW_MAINNET_EXTERNAL="false"
# ----------------------------------------

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# ASCII Art Welcome Message
echo -e "${CYAN}"
echo "                                                                                                        "
echo "   ______          __             __        ____             __                   _   __          __    "
echo "  /_  _____  _____/ /_____  ___  / /_      / __ \____  _____/ /_____  _____      / | / ____  ____/ ___  "
echo "   / / / _ \/ ___/ __/ __ \/ _ \/ ________/ / / / __ \/ ___/ //_/ _ \/ _________/  |/ / __ \/ __  / _ \ "
echo "  / / /  __(__  / /_/ / / /  __/ /_/_____/ /_/ / /_/ / /__/ ,< /  __/ /  /_____/ /|  / /_/ / /_/ /  __/ "
echo " /_/  \___/____/\__/_/ /_/\___/\__/     /_____/\____/\___/_/|_|\___/_/        /_/ |_/\____/\__,_/\___/  "
echo "                                                                                                        "                                                                                                 
echo

# Function to show currently running nodes
show_running_nodes() {
  local running_nodes

  running_nodes=$(docker ps --format "{{.Names}}" | grep -E "^node-[^-]+-[^-]+-container$" || true)

  if [ -n "$running_nodes" ]; then
    echo -e "${CYAN}Currently running Cardano node(s):${NC}"
    echo "$running_nodes" | while read -r container; do
      # Extract network and version from container name (node-network-version-container)
      local network_version=$(echo "$container" | sed 's/node-\(.*\)-container/\1/')
      echo -e "  ${GREEN}✓${NC} ${CYAN}$container${NC} (${YELLOW}$network_version${NC})"
    done
    echo ""
  else
    echo -e "${YELLOW}No Cardano nodes are currently running.${NC}"
    echo ""
  fi
}

# Show running nodes at startup
show_running_nodes

# Prompt the user to select connection type first
echo -e "${CYAN}How would you like to connect to a Cardano node?${NC}"
connection_options=("Start a new Docker node" "Configure connection to an external node via socket file")
select connection_type in "${connection_options[@]}"; do
  if [ -n "$connection_type" ]; then
    echo -e "${GREEN}You have selected: $connection_type${NC}"
    break
  else
    echo -e "${RED}Invalid selection. Please try again.${NC}"
  fi
done

# Define the list of available networks
available_networks=("mainnet" "preprod" "preview" "sanchonet")


# If user selected external node configuration
if [ "$connection_type" = "Configure connection to an external node via socket file" ]; then
  echo
  echo -e "${CYAN}Checking external node configuration...${NC}"
  
  # Check if environment variables are set (use parameter expansion to handle unbound variables)
  if [ -z "${CARDANO_NODE_SOCKET_PATH:-}" ]; then
    echo -e "${RED}Error: CARDANO_NODE_SOCKET_PATH environment variable is not set.${NC}"
    echo -e "${YELLOW}Please set it before running this script:${NC}"
    echo -e "${BLUE}  export CARDANO_NODE_SOCKET_PATH=\"/path/to/node.socket\"${NC}"
    exit 1
  fi
  
  if [ -z "${CARDANO_NODE_NETWORK_ID:-}" ]; then
    echo -e "${RED}Error: CARDANO_NODE_NETWORK_ID environment variable is not set.${NC}"
    echo -e "${YELLOW}Please set it before running this script:${NC}"
    echo -e "${BLUE}  export CARDANO_NODE_NETWORK_ID=1  # 1=preprod, 2=preview, 4=sanchonet${NC}"
    exit 1
  fi
  
  # Expand ~ in socket path
  socket_path="${CARDANO_NODE_SOCKET_PATH/#\~/$HOME}"
  
  # Validate socket file exists
  if [ ! -S "$socket_path" ] && [ ! -f "$socket_path" ]; then
    echo -e "${RED}Error: Socket file '$socket_path' does not exist or is not accessible.${NC}"
    echo -e "${YELLOW}Please check that CARDANO_NODE_SOCKET_PATH points to a valid socket file.${NC}"
    exit 1
  fi
  
  # Validate socket file extension
  if [[ "$socket_path" != *.socket ]]; then
    echo -e "${YELLOW}Warning: Socket file should have .socket extension.${NC}"
  fi
  
  # Validate socket file is actually a socket file type
  if [ ! -S "$socket_path" ]; then
    echo -e "${YELLOW}Warning: '$socket_path' exists but is not a socket file type.${NC}"
    echo -e "${CYAN}Do you want to continue anyway? (y/n):${NC}"
    read -r continue_choice < /dev/tty
    if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
      echo -e "${YELLOW}Cancelled.${NC}"
      exit 0
    fi
  fi
  
  # Validate network ID is numeric
  if ! [[ "${CARDANO_NODE_NETWORK_ID:-}" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: CARDANO_NODE_NETWORK_ID must be a number.${NC}"
    exit 1
  fi
  
  # Block mainnet for external nodes
  if [ "${CARDANO_NODE_NETWORK_ID:-}" = "764824073" ] && [ "${ALLOW_MAINNET_EXTERNAL:-}" != "true" ]; then
    echo -e "${RED}Error: Mainnet connections via external sockets are not allowed for security reasons.${NC}"
    echo -e "${YELLOW}Please use Docker mode for mainnet, or set CARDANO_NODE_NETWORK_ID to a testnet value (1, 2, or 4).${NC}"
    exit 1
  fi
  
  # Determine network name from ID
  case "${CARDANO_NODE_NETWORK_ID:-}" in
    1) network_name="preprod" ;;
    2) network_name="preview" ;;
    4) network_name="sanchonet" ;;
    *) network_name="unknown" ;;
  esac
  
  # Confirm with user
  echo
  echo -e "${GREEN}External node configuration detected:${NC}"
  echo -e "${BLUE}  Socket path: $socket_path${NC}"
  echo -e "${BLUE}  Network ID: ${CARDANO_NODE_NETWORK_ID:-}${NC}"
  if [ "$network_name" != "unknown" ]; then
    echo -e "${BLUE}  Network: $network_name${NC}"
  fi
  echo
  echo -e "${CYAN}Is this correct? (y/n):${NC}"
  read -r confirm < /dev/tty
  
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo -e "${YELLOW}Cancelled. Please set the correct environment variables and try again.${NC}"
    exit 0
  fi
  
  echo
  echo -e "${GREEN}Configuration confirmed!${NC}"
  echo -e "${BLUE}You can now run scripts with these environment variables set.${NC}"
  echo
  echo -e "${BLUE}Example:${NC}"
  echo -e "${YELLOW}  ./scripts/query/tip.sh${NC}"
  exit 0
fi

# Continue with Docker node setup
echo
echo -e "${CYAN}Setting up Docker node...${NC}"

# Define the list of available node versions
available_versions=( "10.5.3" "10.5.1")

# Initialize variables to avoid unbound variable errors
network=""
node_version=""

# Check if running in non-interactive mode (e.g., CI/CD)
if [ ! -t 0 ]; then
  # Non-interactive mode: read from stdin
  read -r network_choice || true
  if [ -n "$network_choice" ] && [ "$network_choice" -ge 1 ] && [ "$network_choice" -le ${#available_networks[@]} ]; then
    network="${available_networks[$((network_choice - 1))]}"
    echo -e "${GREEN}Selected network: $network${NC}"
  else
    echo -e "${RED}Error: Invalid network selection: $network_choice${NC}"
    exit 1
  fi
  
  read -r version_choice || true
  if [ -n "$version_choice" ] && [ "$version_choice" -ge 1 ] && [ "$version_choice" -le ${#available_versions[@]} ]; then
    node_version="${available_versions[$((version_choice - 1))]}"
    echo -e "${GREEN}Selected node version: $node_version${NC}"
  else
    echo -e "${RED}Error: Invalid version selection: $version_choice${NC}"
    exit 1
  fi
else
  # Interactive mode: use select
  echo -e "${CYAN}Please select a network:${NC}"
  select network in "${available_networks[@]}"; do
    if [ -n "$network" ]; then
      echo -e "${GREEN}You have selected: $network${NC}"
      break
    else
      echo -e "${RED}Invalid selection. Please try again.${NC}"
    fi
  done
  
  echo -e "${CYAN}Please select a node version:${NC}"
  select node_version in "${available_versions[@]}"; do
    if [ -n "$node_version" ]; then
      echo -e "${GREEN}You have selected: $node_version${NC}"
      break
    else
      echo -e "${RED}Invalid selection. Please try again.${NC}"
    fi
  done
fi

# Function to assign a unique port based on version
# This ensures different versions on the same network use different ports
assign_port_for_version() {
  local version=$1
  local base_port=3001
  
  # Create a simple hash from version string to get consistent port assignment
  # Convert version like "10.5.1" to a number for port offset
  # Remove dots and take modulo to get offset (0-99 range)
  local version_no_dots=$(echo "$version" | tr -d '.')
  local version_num=$((10#$version_no_dots))  # Force base-10 interpretation
  local offset=$((version_num % 100))
  local port=$((base_port + offset))
  
  echo $port
}

# Validate that both network and node_version are set
if [ -z "$network" ]; then
  echo -e "${RED}Error: Network not selected${NC}"
  exit 1
fi

if [ -z "$node_version" ]; then
  echo -e "${RED}Error: Node version not selected${NC}"
  exit 1
fi

# Check for running Cardano node containers
check_running_nodes() {
  local running_nodes
  running_nodes=$(docker ps --format "{{.Names}}" | grep -E "^node-[^-]+-[^-]+-container$" || true)
  
  if [ -n "$running_nodes" ]; then
    echo -e "${YELLOW}Warning: You have the following Cardano node(s) already running:${NC}"
    echo "$running_nodes" | while read -r container; do
      echo -e "  ${CYAN}- $container${NC}"
    done
    echo ""
  else
    echo -e "${GREEN}No Cardano nodes are currently running.${NC}"
    echo ""
  fi
  
  echo "$running_nodes"
}

# Check if the specific node is already running or exists
check_duplicate_node() {
  local target_container="node-$network-$node_version-container"
  local is_running
  local exists
  
  # Check if container is running
  is_running=$(docker ps --format "{{.Names}}" | grep -E "^${target_container}$" || true)
  
  # Check if container exists (even if stopped)
  exists=$(docker ps -a --format "{{.Names}}" | grep -E "^${target_container}$" || true)
  
  if [ -n "$is_running" ]; then
    echo -e "${RED}Error: Node '$target_container' is already running!${NC}"
    echo -e "${YELLOW}Please stop it first using: ./stop-nodes.sh${NC}"
    echo -e "${YELLOW}Or use a different network/version combination.${NC}"
    exit 1
  elif [ -n "$exists" ]; then
    echo -e "${YELLOW}Warning: Container '$target_container' exists but is not running.${NC}"
    echo -e "${YELLOW}Removing existing container...${NC}"
    docker rm -f "$target_container" 2>/dev/null || true
  fi
}

# Check for running nodes and display them
running_nodes=$(check_running_nodes)

# Check if the specific node is already running
check_duplicate_node

# Assign a unique port for this version
NODE_PORT=$(assign_port_for_version "$node_version")
echo -e "${BLUE}Assigned port: $NODE_PORT${NC}"

# Get the project root directory (where this script is located)
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir" && pwd)

# Set directory locations
base_dir="$project_root"
node_dir="$base_dir/node-$network-$node_version"
config_dir="$node_dir/config"
db_dir="$node_dir/db"
ipc_dir="$node_dir/ipc"

# Transaction dirs
tx_dir="$base_dir/txs"
stake_dir="$tx_dir/stake"
cc_dir="$tx_dir/cc"
drep_dir="$tx_dir/drep"
ga_dir="$tx_dir/ga"
multi_sig_dir="$tx_dir/multi-sig"
simple_dir="$tx_dir/simple"
helper_dir="$tx_dir/helper"

dumps_dir="$base_dir/dumps/$network"
utilities_dir="$base_dir/utilities"

# Base URL for node config files
if [ "$network" = "sanchonet" ]; then
  config_base_url="https://raw.githubusercontent.com/Hornan7/SanchoNet-Tutorials/refs/heads/main/genesis/"
else
  config_base_url="https://book.play.dev.cardano.org/environments/$network/"
fi

# Function to create a directory if it doesn't exist
create_dir() {
  local dir=$1
  if [ ! -d "$dir" ]; then
    echo -e "${YELLOW}Creating directory: $dir${NC}"
    mkdir -p "$dir"
  fi
}

# Function to remove and recreate a directory
reset_dir() {
  local dir=$1
  if [ -d "$dir" ]; then
    echo -e "${YELLOW}Resetting directory: $dir${NC}"
    rm -rf "$dir"
  fi
  mkdir -p "$dir"
}

# Create necessary directories
create_dir "$db_dir"
reset_dir "$ipc_dir"
create_dir "$config_dir"
# Transaction dirs
create_dir "$tx_dir"
create_dir "$stake_dir"
create_dir "$cc_dir"
create_dir "$drep_dir"
create_dir "$ga_dir"
create_dir "$multi_sig_dir"
create_dir "$simple_dir"
create_dir "$helper_dir"
# Dumps dir
create_dir "$dumps_dir"
# Utilities dir
create_dir "$utilities_dir"

# List of JSON files to download
config_files=(
  "config.json"
  "topology.json"
  "byron-genesis.json"
  "shelley-genesis.json"
  "alonzo-genesis.json"
  "conway-genesis.json"
  "peer-snapshot.json"
  "guardrails-script.plutus"
)

# Change directory to the config directory and download files
echo -e "${CYAN}Downloading configuration files...${NC}"
cd "$config_dir" || exit
for file in "${config_files[@]}"; do
  echo -e "${BLUE}Downloading: $file${NC}"
  curl --silent -O -J -L "${config_base_url}${file}"
done

# Return to the base directory
cd "$base_dir" || exit

# Export environment variables for use in docker-compose.yml
export NETWORK=$network
export NODE_VERSION=$node_version
export NODE_PORT=$NODE_PORT

# Get the network magic from the shelley-genesis.json file and pass it into the container
export NETWORK_ID=$(jq -r '.networkMagic' "$config_dir/shelley-genesis.json")

# Substitute the variables in the docker-compose.yml file and start the Docker container
echo -e "${CYAN}Starting the Docker container...${NC}"
# Use docker compose (plugin) if available, fallback to docker-compose (standalone)
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  envsubst < docker-compose.yml | docker compose -f - up -d --build
elif command -v docker-compose >/dev/null 2>&1; then
  envsubst < docker-compose.yml | docker-compose -f - up -d --build
else
  echo -e "${RED}Error: Neither 'docker compose' nor 'docker-compose' is available${NC}"
  exit 1
fi

# Forward the logs to the terminal
echo -e "${GREEN}Docker container logs:${NC}"
echo -e "${BLUE}Container name: node-$network-$node_version-container${NC}"
echo -e "${BLUE}To use this container with scripts, you can specify:${NC}"
echo -e "${YELLOW}  CARDANO_CONTAINER_NAME=\"node-$network-$node_version-container\" ./scripts/query/tip.sh${NC}"
echo -e "${BLUE}Or let the script auto-select if it's the only running container.${NC}"
echo
docker logs "node-$network-$node_version-container" --follow