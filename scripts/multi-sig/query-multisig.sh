#!/bin/bash
set -euo pipefail

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"

# Check required files exist
if [ ! -f "$keys_dir/multi-sig/script.addr" ]; then
  echo "Error: Multi-sig script address not found: $keys_dir/multi-sig/script.addr"
  echo "Please run scripts/multi-sig/generate-keys-and-script.sh first"
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

script_addr=$(cat "$keys_dir/multi-sig/script.addr")
echo "Querying UTXOs for your multisig script address: $script_addr"

# Query the UTxOs controlled by multisig script address
container_cli conway query utxo \
  --address "$script_addr" \
  --out-file /dev/stdout