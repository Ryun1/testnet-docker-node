#!/bin/bash

# Define directories
keys_dir="./keys"
txs_dir="./txs/combine-utxos"

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

# build command
container_cli conway transaction build \
  --witness-override 1 \
    $(container_cli query utxo --address $(cat "$keys_dir/payment.addr") --out-file /dev/stdout \
        | jq -r 'to_entries 
        | map(select(.value.datum == null and .value.datumhash == null and .value.inlineDatum == null and .value.inlineDatumRaw == null and .value.referenceScript == null)) 
        | map(" --tx-in " + .key) 
        | .[]') \
  --change-address $(cat "$keys_dir/payment.addr") \
  --out-file "$txs_dir/combine-tx.unsigned"

# Sign transaction
container_cli conway transaction sign \
  --tx-body-file "$txs_dir/combine-tx.unsigned" \
  --signing-key-file "$keys_dir/payment.skey" \
  --out-file "$txs_dir/combine-tx.signed"

# Submit transaction
container_cli conway transaction submit \
  --tx-file "$txs_dir/combine-tx.signed"
