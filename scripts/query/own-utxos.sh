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


# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

payment_addr=$(cat "$keys_dir/payment.addr")
echo "Querying UTXOs for your address: $payment_addr"

# Query the UTxOs controlled by the payment address

cardano_cli conway query utxo \
  --address "$(cat $keys_dir/payment.addr)" \
  --out-file  /dev/stdout
