#!/bin/bash
set -euo pipefail

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"

# Check if you have a address created
if [ ! -f "$keys_dir/payment.addr" ]; then
  echo "Please generate some keys and addresses before querying funds."
  echo "Exiting."
  exit 0
fi

if [ ! -f "$keys_dir/stake.addr" ]; then
  echo "Error: Stake address file not found: $keys_dir/stake.addr"
  echo "Please run scripts/generate-keys.sh first"
  exit 1
fi

# Get the container name from the get-container script
container_name="$("$script_dir/../helper/get-container.sh")"

if [ -z "$container_name" ]; then
  echo "Failed to determine a running container."
  exit 1
fi

echo "Using running container: $container_name"

# Function to execute cardano-cli commands inside the container
container_cli() {
  docker exec -ti "$container_name" cardano-cli "$@"
}

stake_addr=$(cat "$keys_dir/stake.addr")
echo "Querying Stake Account info for your address: $stake_addr"

container_cli conway query stake-address-info \
  --address "$stake_addr" \
  --out-file /dev/stdout
