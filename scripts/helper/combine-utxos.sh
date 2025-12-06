#!/bin/bash
set -euo pipefail

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/helper"
tx_unsigned="$txs_dir/combine-utxos-tx.unsigned"
tx_signed="$txs_dir/combine-utxos-tx.signed"

# Create transaction directory if it doesn't exist
mkdir -p "$txs_dir"

# Check required files exist
if [ ! -f "$keys_dir/payment.addr" ]; then
  echo "Error: Payment address file not found: $keys_dir/payment.addr"
  echo "Please run scripts/generate-keys.sh first"
  exit 1
fi

if [ ! -f "$keys_dir/payment.skey" ]; then
  echo "Error: Payment signing key not found: $keys_dir/payment.skey"
  exit 1
fi


# Source the cardano-cli wrapper
source "$script_dir/cardano-cli-wrapper.sh"

payment_addr=$(cat "$keys_dir/payment.addr")
echo "Combining all only ada UTxOs at $payment_addr"

# build transaction

cardano_cli conway transaction build \
    $(cardano_cli conway query utxo --address $(cat "$keys_dir/payment.addr") --out-file /dev/stdout \
        | jq -r 'to_entries 
        | map(select(.value.datum == null and .value.datumhash == null and .value.inlineDatum == null and .value.inlineDatumRaw == null and .value.referenceScript == null)) 
        | map(" --tx-in " + .key) 
        | .[]') \
  --change-address "$payment_addr" \
  --out-file "$tx_unsigned"

# Check transaction file was created
if [ ! -f "$tx_unsigned" ]; then
  echo "Error: Failed to create unsigned transaction file"
  exit 1
fi

# Sign transaction

cardano_cli conway transaction sign \
  --tx-body-file "$tx_unsigned" \
  --signing-key-file "$keys_dir/payment.skey" \
  --out-file "$tx_signed"

# Check signed transaction file was created
if [ ! -f "$tx_signed" ]; then
  echo "Error: Failed to create signed transaction file"
  exit 1
fi

# Submit transaction

cardano_cli conway transaction submit \
  --tx-file "$tx_signed"
