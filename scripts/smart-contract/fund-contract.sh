#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
amount=5000000
script_location="https://raw.githubusercontent.com/Ryun1/idk-aiken/refs/heads/main/script.json"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directories
keys_dir="./keys"
txs_dir="./txs/smart-contract"

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

# Send five ada to script address
echo "Sending $amount lovelace to script"

# Download the script
echo "Downloading script from $script_location"
curl -s -o $txs_dir/script.json $script_location

# Check if the script file exists
if [ ! -f "$txs_dir/script.json" ]; then
  echo "Script file not found: $txs_dir/script.json"
  exit 1
fi

# Get the script address
container_cli conway address build \
  --payment-script-file $txs_dir/script.json \
  --out-file $txs_dir/script.addr

echo "Script address: $(cat $txs_dir/script.addr)"

# Get payment key hash
payment_key_hash="$(container_cli address key-hash --payment-verification-key-file "$keys_dir/payment.vkey" | cut -c1-56)"

echo "building datum.json with payment key hash: $payment_key_hash"
echo "{\"constructor\": 0, \"fields\": [{ \"bytes\": \"$payment_key_hash\" }]}" > $txs_dir/datum.json

# build the transaction
echo "Building transaction"

container_cli conway transaction build \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[1]')" \
 --tx-out "$(cat $txs_dir/script.addr)+$amount" \
 --tx-out-inline-datum-file $txs_dir/datum.json \
 --change-address "$(cat $keys_dir/payment.addr)" \
 --out-file $txs_dir/fund-script.unsigned

# Sing the transaction
echo "Signing transaction"

container_cli conway transaction sign \
 --tx-body-file $txs_dir/fund-script.unsigned \
 --signing-key-file $keys_dir/payment.skey \
 --out-file $txs_dir/fund-script.signed

# Submit Transaction
echo "Submitting transaction"

container_cli conway transaction submit \
 --tx-file $txs_dir/fund-script.signed

