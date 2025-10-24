#!/bin/bash

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

# Check if you have a address created
if [ ! -f "$keys_dir/payment.addr" ]; then
  echo "Please generate some keys and addresses before querying funds."
  echo "Exiting."
  exit 0
fi

echo "Querying Stake Account info for your address: $(cat $keys_dir/stake.addr)"

container_cli conway query stake-address-info \
  --address "$(cat $keys_dir/stake.addr)" \
  --out-file  /dev/stdout
