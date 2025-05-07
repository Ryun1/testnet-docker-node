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

echo "Resigning your CC cold key."

# Generate CC cold key resignation certificate
container_cli conway governance committee create-cold-key-resignation-certificate \
  --cold-verification-key-file "$keys_dir/cc-cold.vkey" \
  --out-file "$txs_dir/resign-cold.cert"

# Build transaction
echo "Building transaction"

container_cli conway transaction build \
  --witness-override 2 \
  --tx-in $(container_cli conway query utxo --address $(cat "$keys_dir/payment.addr") --out-file /dev/stdout | jq -r 'keys[0]') \
  --change-address $(cat "$keys_dir/payment.addr") \
  --certificate-file "$txs_dir/resign-cold.cert" \
  --out-file "$txs_dir/resign-cold-tx.unsigned"

# Sign transaction
echo "Signing transaction"

container_cli conway transaction sign \
  --tx-body-file "$txs_dir/resign-cold-tx.unsigned" \
  --signing-key-file "$keys_dir/payment.skey" \
  --signing-key-file "$keys_dir/cc-cold.skey" \
  --out-file "$txs_dir/resign-cold-tx.signed"

# Submit transaction
echo "Submitting transaction"

container_cli conway transaction submit \
  --tx-file "$txs_dir/resign-cold-tx.signed"