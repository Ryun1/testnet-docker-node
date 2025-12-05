#!/bin/bash

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"

# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

# Generate hot CC keys
echo "Generating a new constitutional committee hot key (replacing the existing one)."

# Generate CC hot keys
cardano_cli conway governance committee key-gen-hot \
  --verification-key-file "$keys_dir/cc-hot.vkey" \
  --signing-key-file "$keys_dir/cc-hot.skey"

# Generate CC hot key hash
cardano_cli conway governance committee key-hash \
  --verification-key-file "$keys_dir/cc-hot.vkey" > "$keys_dir/cc-hot-key-hash.hash"