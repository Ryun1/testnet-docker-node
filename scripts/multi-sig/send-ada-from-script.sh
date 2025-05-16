#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
LOVELACE_AMOUNT=1000000
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directory paths
keys_dir="./keys"
txs_dir="./txs/multi-sig"
tx_path_stub="$txs_dir/send-ada-from-script"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

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
echo "Sending $LOVELACE_AMOUNT lovelace to the payment address from the script."

echo "Building transaction"

container_cli conway transaction build \
 --tx-in $(container_cli conway query utxo --address $(cat $keys_dir/multi-sig/script.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --tx-in-script-file $keys_dir/multi-sig/script.json \
 --tx-out $(cat $keys_dir/payment.addr)+$LOVELACE_AMOUNT \
 --change-address $(cat $keys_dir/multi-sig/script.addr) \
 --required-signer-hash "$(cat $keys_dir/multi-sig/1.keyhash)" \
 --required-signer-hash "$(cat $keys_dir/multi-sig/2.keyhash)" \
 --required-signer-hash "$(cat $keys_dir/multi-sig/3.keyhash)" \
 --out-file "$txs_unsigned_path"

# Create multisig witnesses
container_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file $keys_dir/multi-sig/1.skey \
  --out-file "$tx_path_stub-1.witness"

container_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file $keys_dir/multi-sig/2.skey \
  --out-file "$tx_path_stub-2.witness"

container_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file $keys_dir/multi-sig/3.skey \
  --out-file "$tx_path_stub-3.witness"

# Create witness
container_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file $keys_dir/payment.skey \
  --out-file "$tx_path_stub-payment.witness"

# Assemble Transaction
container_cli conway transaction assemble \
  --tx-body-file "$tx_unsigned_path" \
  --witness-file "$tx_path_stub-payment.witness" \
  --witness-file "$tx_path_stub-2.witness" \
  --witness-file "$tx_path_stub-3.witness" \
  --witness-file "$tx_path_stub-3.witness" \
  --out-file "$tx_signed_path"

# Submit the transaction
echo "Submitting transaction"

if container_cli conway transaction submit --tx-file $tx_signed_path; then
  # Get the transaction ID
  transaction_id=$(container_cli conway transaction txid --tx-file $tx_signed_path)
  echo "Follow the transaction at: $transaction_id"
else
  echo "Transaction submission failed."
  exit 1
fi
