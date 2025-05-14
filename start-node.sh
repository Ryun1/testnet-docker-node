#!/bin/bash

# Define the list of available networks
available_networks=("mainnet" "preprod" "preview" "sanchonet")

# Prompt the user to select a network
echo "Please select a network:"
select network in "${available_networks[@]}"; do
  if [ -n "$network" ]; then
    echo "You have selected: $network"
    break
  else
    echo "Invalid selection. Please try again."
  fi
done

# Set directory locations
base_dir="$(pwd)"
node_dir="$base_dir/node-$network"
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
smart_contract_dir="$tx_dir/smart-contract"

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
    mkdir -p "$dir"
  fi
}

# Function to remove and recreate a directory
reset_dir() {
  local dir=$1
  if [ -d "$dir" ]; then
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
create_dir "$smart_contract_dir"
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
)

# Change directory to the config directory and download files
cd "$config_dir" || exit
for file in "${config_files[@]}"; do
  curl --silent -O -J -L "${config_base_url}${file}"
done

# Return to the base directory
cd "$base_dir" || exit

# Export environment variables for use in docker-compose.yml
export NETWORK=$network

# Get the network magic from the shelley-genesis.json file and pass it into the container
export NETWORK_ID=$(jq -r '.networkMagic' "$config_dir/shelley-genesis.json")

# Substitute the variables in the docker-compose.yml file and start the Docker container
envsubst < docker-compose.yml | docker-compose -f - up -d --build

# Forward the logs to the terminal
docker logs "node-$network-container" --follow