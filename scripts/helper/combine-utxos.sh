#!/bin/bash
set -euo pipefail

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/helper"

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

# Get the container name from the get-container script
container_name="$("$script_dir/../helper/get-container.sh")"

if [ -z "$container_name" ]; then
  echo "Failed to determine a running container."
  exit 1
fi

echo "Using running container: $container_name"

# Function to execute cardano-cli commands inside the container
container_cli() {
  docker exec -ti "$container_name" cardano-cli "$@"
}

payment_addr=$(cat "$keys_dir/payment.addr")
echo "Combining all only ada UTxOs at $payment_addr"

# build transaction
tx_unsigned="$txs_dir/combine-utxos-tx.unsigned"
tx_signed="$txs_dir/combine-utxos-tx.signed"

container_cli conway transaction build \
    $(container_cli conway query utxo --address "$payment_addr" --out-file /dev/stdout \
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
container_cli conway transaction sign \
  --tx-body-file "$tx_unsigned" \
  --signing-key-file "$keys_dir/payment.skey" \
  --out-file "$tx_signed"

# Check signed transaction file was created
if [ ! -f "$tx_signed" ]; then
  echo "Error: Failed to create signed transaction file"
  exit 1
fi

# Submit transaction
container_cli conway transaction submit \
  --tx-file "$tx_signed"
