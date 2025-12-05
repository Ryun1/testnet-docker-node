#!/bin/bash

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/helper"

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

echo "Combining all only ada UTxOs at $(cat "$keys_dir/payment.addr")"

# build transaction
container_cli conway transaction build \
    $(container_cli query utxo --address $(cat "$keys_dir/payment.addr") --out-file /dev/stdout \
        | jq -r 'to_entries 
        | map(select(.value.datum == null and .value.datumhash == null and .value.inlineDatum == null and .value.inlineDatumRaw == null and .value.referenceScript == null)) 
        | map(" --tx-in " + .key) 
        | .[]') \
  --change-address $(cat "$keys_dir/payment.addr") \
  --out-file "$txs_dir/combine-utxos-tx.unsigned"

# Sign transaction
container_cli conway transaction sign \
  --tx-body-file "$txs_dir/combine-utxos-tx.unsigned" \
  --signing-key-file "$keys_dir/payment.skey" \
  --out-file "$txs_dir/combine-utxos-tx.signed"

# Submit transaction
container_cli conway transaction submit \
  --tx-file "$txs_dir/combine-utxos-tx.signed"
