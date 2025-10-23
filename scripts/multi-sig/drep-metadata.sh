#!/bin/bash

# Define directory paths
keys_dir="./keys"
txs_dir="./txs/multi-sig"
tx_path_stub="$txs_dir/one-sig-drep-vote"
tx_cert_path="$tx_path_stub-update.cert"
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

echo "Building DRep Update Certificate"

container_cli conway governance drep update-certificate \
 --drep-script-hash $(cat $txs_dir/drep-one-sig.id) \
 --out-file $tx_cert_path

echo "Building transaction"


container_cli conway transaction build \
 --tx-in $(container_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --change-address $(cat $keys_dir/payment.addr) \
 --required-signer-hash "$(cat $keys_dir/multi-sig/1.keyhash)" \
 --certificate-file $tx_cert_path \
 --certificate-script-file $txs_dir/drep-one-sig.json \
 --metadata-json-file $txs_dir/metadata.json \
 --out-file "$tx_unsigned_path"

# Create multisig witnesses
container_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file $keys_dir/multi-sig/1.skey \
  --out-file "$tx_path_stub-1.witness"

# Create witness
container_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file $keys_dir/payment.skey \
  --out-file "$tx_path_stub-payment.witness"

# Assemble Transaction
container_cli conway transaction assemble \
  --tx-body-file "$tx_unsigned_path" \
  --witness-file "$tx_path_stub-payment.witness" \
  --witness-file "$tx_path_stub-1.witness" \
  --out-file "$tx_signed_path"

# Submit the transaction
echo "Submitting transaction"

container_cli conway transaction submit --tx-file $tx_signed_path
