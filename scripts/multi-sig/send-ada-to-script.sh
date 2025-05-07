#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
LOVELACE_AMOUNT=10000000
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directories
keys_dir="./keys"
txs_dir="./txs/ga"

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

# Send ada to the multisig payment script
echo "Sending $LOVELACE_AMOUNT lovelace to the multisig payment address."

echo "Building transaction"

container_cli conway transaction build \
 --tx-in $(container_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --tx-out $(cat $keys_dir/multi-sig/script.addr)+$LOVELACE_AMOUNT \
 --change-address $(cat $keys_dir/payment.addr) \
 --out-file $txs_dir/multi-sig/send-ada-to-script.unsigned

container_cli conway transaction sign \
  --tx-body-file $txs_dir/multi-sig/send-ada-to-script.unsigned \
  --signing-key-file $keys_dir/payment.skey \
  --out-file $txs_dir/multi-sig/send-ada-to-script.signed

echo "Submitting transaction"

container_cli conway transaction submit \
 --tx-file $txs_dir/multi-sig/send-ada-to-script.signed
