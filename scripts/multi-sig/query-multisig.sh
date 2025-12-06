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


# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

script_addr=$(cat "$keys_dir/multi-sig/script.addr")
echo "Querying UTXOs for your multisig script address: $script_addr"

# Query the UTxOs controlled by multisig script address

cardano_cli conway query utxo \
  --address "$(cat $keys_dir/multi-sig/script.addr)" \
  --out-file  /dev/stdout
