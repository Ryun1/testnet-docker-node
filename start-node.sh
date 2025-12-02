#!/bin/bash

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
echo -e "${NC}"
echo -e "${GREEN}Welcome to the Testnet Docker Node!${NC}"
echo -e "${YELLOW}This script will help you set up and manage your Cardano testnet node(s).${NC}"
echo

# Define the list of available networks
available_networks=("mainnet" "preprod" "preview" "sanchonet")

# Prompt the user to select a network
echo -e "${CYAN}Please select a network:${NC}"
select network in "${available_networks[@]}"; do
  if [ -n "$network" ]; then
    echo -e "${GREEN}You have selected: $network${NC}"
    break
  else
    echo -e "${RED}Invalid selection. Please try again.${NC}"
  fi
done

# Define the list of available node versions
available_versions=("10.5.1" "10.5.3" "10.6.1")

# Prompt the user to select a node version
echo -e "${CYAN}Please select a node version:${NC}"
select node_version in "${available_versions[@]}"; do
  if [ -n "$node_version" ]; then
    echo -e "${GREEN}You have selected: $node_version${NC}"
    break
  else
    echo -e "${RED}Invalid selection. Please try again.${NC}"
  fi
done

# Set directory locations
base_dir="$(pwd)"
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

# Dumps dir
dumps_dir="./dumps/$network"

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
# Dumps dir
create_dir "$dumps_dir"

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

# Get the network magic from the shelley-genesis.json file and pass it into the container
export NETWORK_ID=$(jq -r '.networkMagic' "$config_dir/shelley-genesis.json")

# Substitute the variables in the docker-compose.yml file and start the Docker container
echo -e "${CYAN}Starting the Docker container...${NC}"
envsubst < docker-compose.yml | docker-compose -f - up -d --build

# Forward the logs to the terminal
echo -e "${GREEN}Docker container logs:${NC}"
docker logs "node-$network-$node_version-container" --follow