#!/bin/bash

# errors are handled gracefully to tell the user
set -euo pipefail

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

# Function to check if Docker is running
check_docker_running() {

  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not installed.${NC}"
    echo -e "${YELLOW}Please install Docker Desktop from: https://www.docker.com/products/docker-desktop${NC}"
    exit 1
  fi
  
  if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker is installed but not running.${NC}"
    echo -e "${YELLOW}Please start Docker Desktop and try again.${NC}"
    exit 1
  fi
}

# Check Docker before proceeding
check_docker_running

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

# Function to list existing node directories
list_existing_node_directories() {
  local script_dir=$(dirname "$0")
  local project_root=$(cd "$script_dir" && pwd)
  local node_dirs
  local found_any=false
  
  # Find all node-* directories
  node_dirs=$(find "$project_root" -maxdepth 1 -type d -name "node-*" 2>/dev/null | sort || true)
  
  if [ -n "$node_dirs" ]; then
    echo -e "${CYAN}Existing Node directories:${NC}"
    while IFS= read -r dir; do
      [ -z "$dir" ] && continue
      local dirname=$(basename "$dir")
      # Extract network and version from directory name
      # Pattern: node-network-version or node-network
      if [[ "$dirname" =~ ^node-(.+)-([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        # Has version: node-network-version
        local network="${BASH_REMATCH[1]}"
        local version="${BASH_REMATCH[2]}"
        # Capitalize first letter of network
        network=$(echo "$network" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
        # Handle special case: sanchonet -> SanchoNet
        if [ "$network" = "Sanchonet" ]; then
          network="SanchoNet"
        fi
        echo -e "  ${GREEN}-${NC} ${CYAN}$network $version${NC}"
        found_any=true
      elif [[ "$dirname" =~ ^node-(.+)$ ]]; then
        # No version: node-network
        local network="${BASH_REMATCH[1]}"
        # Capitalize first letter of network
        network=$(echo "$network" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
        # Handle special case: sanchonet -> SanchoNet
        if [ "$network" = "Sanchonet" ]; then
          network="SanchoNet"
        fi
        echo -e "  ${GREEN}-${NC} ${CYAN}$network${NC}"
        found_any=true
      fi
    done <<< "$node_dirs"
    if [ "$found_any" = true ]; then
      echo ""
    fi
  fi
}

# Function to show currently running nodes
show_running_nodes() {
  local running_nodes

  running_nodes=$(docker ps --filter "label=managed-by=testnet-docker-node" --format "{{.Names}}" || true)

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

# Show existing node directories at startup
list_existing_node_directories

# Show running nodes at startup
show_running_nodes

# Prompt the user to select connection type first
echo -e "${CYAN}How would you like to connect to a Cardano node?${NC}"
connection_options=("Start a Docker node" "Configure connection to an external node via socket file")
select connection_type in "${connection_options[@]}"; do
  if [ -n "$connection_type" ]; then
    echo -e "${GREEN}You have selected: $connection_type${NC}"
    break
  else
    echo -e "${RED}Invalid selection. Please try again.${NC}"
  fi
done

# Define the list of available networks
available_networks=("sanchonet" "preview" "preprod" "mainnet" "leiosnet")


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
    echo -e "${BLUE}  export CARDANO_NODE_NETWORK_ID=1  # 1=preprod, 2=preview, 4=sanchonet, 5=leiosnet${NC}"
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
    5) network_name="leiosnet" ;;
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

# ----------------------------------------
# Define available node versions per network
# ----------------------------------------
versions_sanchonet=( "11.0.1" )
versions_preview=( "11.0.1" )
versions_preprod=( "11.0.1" "10.6.2" "10.5.4" )
versions_mainnet=( "10.6.2" "10.5.4" )
versions_leiosnet=( "leios-image" )
# ----------------------------------------

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
fi

# Load the available versions for the selected network
versions_var="versions_${network}"
available_versions=()
eval 'available_versions=("${'"$versions_var"'[@]}")'

if [ ${#available_versions[@]} -eq 0 ]; then
  echo -e "${RED}Error: No versions configured for network '$network'.${NC}"
  exit 1
fi

# Select node version
if [ ! -t 0 ]; then
  read -r version_choice || true
  if [ -n "$version_choice" ] && [ "$version_choice" -ge 1 ] && [ "$version_choice" -le ${#available_versions[@]} ]; then
    node_version="${available_versions[$((version_choice - 1))]}"
    echo -e "${GREEN}Selected node version: $node_version${NC}"
  else
    echo -e "${RED}Error: Invalid version selection: $version_choice${NC}"
    exit 1
  fi
else
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

# Normalize network name for directory/container naming
network_normalized="$network"

# Function to assign a unique port based on version
# This ensures different versions on the same network use different ports
assign_port_for_version() {
  local version=$1
  local base_port=3001
  
  # Create a simple hash from version string to get consistent port assignment
  # Convert version like "10.5.1" to a number for port offset
  # Remove dots and take modulo to get offset (0-99 range)
  local version_no_dots=$(echo "$version" | tr -d '.')
  local offset
  if [[ "$version_no_dots" =~ ^[0-9]+$ ]]; then
    # Numeric version: derive a consistent offset from the digits
    local version_num=$((10#$version_no_dots))  # Force base-10 interpretation
    offset=$((version_num % 100))
  else
    # Non-numeric version label (e.g. "leios-image"): derive offset from a checksum
    offset=$(( $(echo "$version" | cksum | cut -d' ' -f1) % 100 ))
  fi
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
  running_nodes=$(docker ps --filter "label=managed-by=testnet-docker-node" --format "{{.Names}}" || true)

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
  local target_container="node-$network_normalized-$node_version-container"
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
node_dir="$base_dir/node-$network_normalized-$node_version"
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

dumps_dir="$base_dir/dumps/$network_normalized"
utilities_dir="$base_dir/utilities"

# Base URL for node config files
if [ "$network" = "sanchonet" ]; then
  config_base_url="https://raw.githubusercontent.com/Hornan7/SanchoNet-Tutorials/refs/heads/main/genesis/"
elif [ "$network" = "leiosnet" ]; then
  config_base_url="https://raw.githubusercontent.com/input-output-hk/cardano-playground/refs/heads/next-2026-05-15/docs/environments-pre/leios/"
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
)

# add dijkstra-genesis.json for 10.6.2, 10.7.0, 11.0.1 and all leiosnet versions
if [ "$node_version" = "11.0.1" ] || [ "$node_version" = "10.6.2" ] || [ "$node_version" = "10.7.0" ] || [ "$network" = "leiosnet" ]; then
  config_files+=("dijkstra-genesis.json")
fi

# add checkpoints.json for preview and mainnet (not available for sanchonet or preprod)
if [ "$network" = "preview" ] || [ "$network" = "mainnet" ]; then
  config_files+=("checkpoints.json")
fi

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
export NETWORK=$network_normalized
export NODE_VERSION=$node_version
export NODE_PORT=$NODE_PORT

# Get the network magic from the shelley-genesis.json file and pass it into the container
export NETWORK_ID=$(jq -r '.networkMagic' "$config_dir/shelley-genesis.json")

# Relay endpoints that serve a side-loadable leios.db snapshot (the SQLite
# database plus its write-ahead log). Tried in order until one succeeds.
leios_db_relays=(
  "https://leios1-rel-a-1.play.dev.cardano.org"
  "https://leios2-rel-b-1.play.dev.cardano.org"
  "https://leios3-rel-c-1.play.dev.cardano.org"
)

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
      echo -e "${GREEN}Side-loaded leios.db into ${dest_dir} (rw).${NC}"
      return 0
    fi
    echo -e "${YELLOW}Relay ${relay} unavailable, trying next...${NC}"
  done

  echo -e "${YELLOW}Warning: could not side-load leios.db from any relay.${NC}"
  echo -e "${YELLOW}The node will start with an empty leios database.${NC}"
  return 1
}

# Select the compose file for this node version.
# The "leios-image" option builds a thin layer (Dockerfile.leios-image) over the
# prebuilt Leios node image published from the ouroboros-leios repo; all other
# versions build the local Dockerfile.
if [ "$node_version" = "leios-image" ]; then
  compose_file="docker-compose.leios-image.yml"
else
  compose_file="docker-compose.yml"
fi

# Use docker compose (plugin) if available, fallback to docker-compose (standalone)
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  compose_cmd="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  compose_cmd="docker-compose"
else
  echo -e "${RED}Error: Neither 'docker compose' nor 'docker-compose' is available${NC}"
  exit 1
fi

# For the Leios image, build the thin patch layer while pulling the latest
# published base image ('main' tag) so updates are picked up on each run.
if [ "$node_version" = "leios-image" ]; then
  echo -e "${CYAN}Pulling and patching the latest Leios node image...${NC}"
  envsubst < "$compose_file" | $compose_cmd -f - build --pull
  # Side-load the leios database from a relay so the node starts from a snapshot.
  download_leios_db "$node_dir/leios" || true
fi

# Substitute the variables in the compose file and start the Docker container
echo -e "${CYAN}Starting the Docker container...${NC}"
envsubst < "$compose_file" | $compose_cmd -f - up -d --build

# Verify the container started successfully
container_name="node-$network_normalized-$node_version-container"

# Give the container a moment to start or fail
sleep 3

# Check if the container is running
container_status=$(docker inspect --format '{{.State.Status}}' "$container_name" 2>/dev/null || echo "not_found")

if [ "$container_status" != "running" ]; then
  echo -e "${RED}Error: Container '$container_name' failed to start (status: $container_status).${NC}"

  # Show the last logs for debugging
  if [ "$container_status" != "not_found" ]; then
    echo -e "${YELLOW}Container logs:${NC}"
    docker logs "$container_name" --tail 20 2>&1 || true
  fi

  # Stop and remove the failed container
  echo -e "${YELLOW}Cleaning up failed container...${NC}"
  NETWORK=$network_normalized NODE_VERSION=$node_version NODE_PORT=$NODE_PORT NETWORK_ID=$NETWORK_ID \
    envsubst < "$compose_file" | $compose_cmd -f - down 2>/dev/null || true
  docker rm -f "$container_name" 2>/dev/null || true

  echo -e "${RED}Container has been stopped and removed. Please check the logs above for details.${NC}"
  exit 1
fi

# Forward the logs to the terminal
echo -e "${GREEN}Docker container started successfully!${NC}"
echo -e "${BLUE}Container name: $container_name${NC}"
echo -e "${BLUE}To use this container with scripts, you can specify:${NC}"
echo -e "${YELLOW}  CARDANO_CONTAINER_NAME=\"$container_name\" ./scripts/query/tip.sh${NC}"
echo -e "${BLUE}Or let the script auto-select if it's the only running container.${NC}"
echo
docker logs "$container_name" --follow