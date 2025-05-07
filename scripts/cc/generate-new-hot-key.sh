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

# Generate hot CC keys
echo "Generating a new constitutional committee hot key (replacing the existing one)."

# Generate CC hot keys
container_cli conway governance committee key-gen-hot \
  --verification-key-file "$keys_dir/cc-hot.vkey" \
  --signing-key-file "$keys_dir/cc-hot.skey"

# Generate CC hot key hash
container_cli conway governance committee key-hash \
  --verification-key-file "$keys_dir/cc-hot.vkey" > "$keys_dir/cc-hot-key-hash.hash"