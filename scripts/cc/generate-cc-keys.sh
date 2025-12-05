#!/bin/bash

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"

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

# Check if CC keys already exist
if [ -f "$keys_dir/cc-cold.vkey" ]; then
    echo "Constitutional committee keys already generated."
    echo "Exiting."
    exit 0
fi

# Generate CC keys
echo "Generating constitutional committee hot and cold keys."

# Generate CC cold keys
container_cli conway governance committee key-gen-cold \
  --verification-key-file "$keys_dir/cc-cold.vkey" \
  --signing-key-file "$keys_dir/cc-cold.skey"

# Generate CC hot keys
container_cli conway governance committee key-gen-hot \
  --verification-key-file "$keys_dir/cc-hot.vkey" \
  --signing-key-file "$keys_dir/cc-hot.skey"

# Generate CC cold key hash
container_cli conway governance committee key-hash \
  --verification-key-file "$keys_dir/cc-cold.vkey" > "$keys_dir/cc-cold-key-hash.hash"

# Generate CC hot key hash
container_cli conway governance committee key-hash \
  --verification-key-file "$keys_dir/cc-hot.vkey" > "$keys_dir/cc-hot-key-hash.hash"