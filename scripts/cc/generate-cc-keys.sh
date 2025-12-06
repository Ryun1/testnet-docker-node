#!/bin/bash

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"

# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

# Check if CC keys already exist
if [ -f "$keys_dir/cc-cold.vkey" ]; then
    echo "Constitutional committee keys already generated."
    echo "Exiting."
    exit 0
fi

# Generate CC keys
echo "Generating constitutional committee hot and cold keys."

# Generate CC cold keys
cardano_cli conway governance committee key-gen-cold \
  --verification-key-file "$keys_dir/cc-cold.vkey" \
  --signing-key-file "$keys_dir/cc-cold.skey"

# Generate CC hot keys
cardano_cli conway governance committee key-gen-hot \
  --verification-key-file "$keys_dir/cc-hot.vkey" \
  --signing-key-file "$keys_dir/cc-hot.skey"

# Generate CC cold key hash
cardano_cli conway governance committee key-hash \
  --verification-key-file "$keys_dir/cc-cold.vkey" > "$keys_dir/cc-cold-key-hash.hash"

# Generate CC hot key hash
cardano_cli conway governance committee key-hash \
  --verification-key-file "$keys_dir/cc-hot.vkey" > "$keys_dir/cc-hot-key-hash.hash"