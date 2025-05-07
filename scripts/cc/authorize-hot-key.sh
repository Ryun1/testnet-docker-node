#!/bin/bash

# Define directories
keys_dir="./keys"
txs_dir="./txs/cc"

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

echo "Authorizing hot key for the constitutional committee."

container_cli conway governance committee create-hot-key-authorization-certificate \
  --cold-verification-key-file "$keys_dir/cc-cold.vkey" \
  --hot-key-file "$keys_dir/cc-hot.vkey" \
  --out-file "$txs_dir/auth-hot.cert"

echo "Building transaction"

container_cli conway transaction build \
  --witness-override 2 \
  --tx-in $(container_cli conway query utxo --address $(cat "$keys_dir/payment.addr") --out-file /dev/stdout | jq -r 'keys[0]') \
  --change-address $(cat "$keys_dir/payment.addr") \
  --certificate-file "$txs_dir/auth-hot.cert" \
  --out-file "$txs_dir/auth-hot-tx.unsigned"

echo "Signing transaction"

container_cli conway transaction sign \
  --tx-body-file "$txs_dir/auth-hot-tx.unsigned" \
  --signing-key-file "$keys_dir/payment.skey" \
  --signing-key-file "$keys_dir/cc-cold.skey" \
  --out-file "$txs_dir/auth-hot-tx.signed"

echo "Submitting transaction"

container_cli conway transaction submit \
  --tx-file "$txs_dir/auth-hot-tx.signed"