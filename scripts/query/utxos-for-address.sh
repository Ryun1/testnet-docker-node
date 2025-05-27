#!/bin/bash


# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
ADDRESS="addr_test1wz0vzkrzked85ywpsq4ffmx2etvjtnk07lvldrp3d4ht86ckfg639"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directories
keys_dir="./keys"

# Get the script's directory
script_dir=$(dirname "$0")

# Get the container name from the get-container script
container_name="$("$script_dir/../helper/get-container.sh")"

if [ -z "$container_name" ]; then
  echo "Failed to determine a running container."
  exit 1
fi

echo "Using running container: $container_name"

# Function to execute cardano-cli commands inside the container
container_cli() {
  docker exec -ti $container_name cardano-cli "$@"
}

echo "Querying UTXOs for address: $ADDRESS"

# Query the UTxOs controlled by the payment address
container_cli conway query utxo \
  --address "$ADDRESS" \
  --out-file  /dev/stdout