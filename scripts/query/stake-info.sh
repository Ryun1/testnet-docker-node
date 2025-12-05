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


# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

stake_addr=$(cat "$keys_dir/stake.addr")
echo "Querying Stake Account info for your address: $stake_addr"


cardano_cli conway query stake-address-info \
  --address "$(cat $keys_dir/stake.addr)" \
  --out-file  /dev/stdout
