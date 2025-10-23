#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
spo_id="pool104flte3y29dprxcntacsuyznhduvlaza38gvp8yyhy2vvmfenxa" # keyhash of the SPO
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directory paths
keys_dir="./keys"
txs_dir="./txs/stake"
tx_path_stub="$txs_dir/stake-pool-deleg"
tx_cert_path="$tx_path_stub.cert"
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

# Delegating to an SPO
echo "Delegating you to SPO: $spo_id."

container-cli conway stake-address stake-delegation-certificate \
 --stake-verification-key-file $keys_dir/stake.vkey \
 --stake-pool-id "$spo_id" \
 --out-file "$tx_cert_path"

container-cli conway transaction build \
 --witness-override 2 \
 --tx-in $(container-cli query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --change-address $(cat $keys_dir/payment.addr) \
 --certificate-file "$tx_cert_path" \
 --out-file "$tx_unsigned_path"

container-cli conway transaction sign \
 --tx-body-file "$tx_unsigned_path" \
 --signing-key-file $keys_dir/payment.skey \
 --signing-key-file $keys_dir/stake.skey \
 --out-file "$tx_signed_path"

# Submit the transaction
echo "Submitting transaction"

container_cli conway transaction submit --tx-file $tx_signed_path
