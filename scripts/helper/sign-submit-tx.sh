#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
TRANSACTION_FILE="treasury-contract"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs"

tx_unsigned_path="$txs_dir/$TRANSACTION_FILE.unsigned"
tx_signed_path="$txs_dir/$TRANSACTION_FILE.signed"

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

# Send ada to the multisig payment script
echo "Signing and submitting $tx_unsigned_path transaction."

container_cli conway transaction sign \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file $keys_dir/payment.skey \
  --out-file "$tx_signed_path"

# Submit the transaction
echo "Submitting transaction"

container_cli conway transaction submit --tx-file $tx_signed_path
