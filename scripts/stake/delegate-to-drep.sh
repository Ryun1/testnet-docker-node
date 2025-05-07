#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
drep_id="3f3d4a84b800b34eb84c6151a955cdd823a0b99e3b886c725b8769e5" # keyhash of the drep
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directories
keys_dir="./keys"
txs_dir="./txs/stake"

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

# Delegating to an DRep
echo "Delegating you to DRep: $drep_id."

container_cli conway stake-address vote-delegation-certificate \
 --stake-verification-key-file $keys_dir/stake.vkey \
 --drep-key-hash "$drep_id" \
 --out-file $txs_dir/vote-deleg-key-hash.cert

echo "Building transaction"

container_cli conway transaction build \
 --witness-override 2 \
 --tx-in $(container_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --change-address $(cat $keys_dir/payment.addr) \
 --certificate-file $txs_dir/vote-deleg-key-hash.cert \
 --out-file $txs_dir/vote-deleg-tx.unsigned

echo "Signing transaction"

container_cli conway transaction sign \
 --tx-body-file $txs_dir/vote-deleg-tx.unsigned \
 --signing-key-file $keys_dir/payment.skey \
 --signing-key-file $keys_dir/stake.skey \
 --out-file $txs_dir/vote-deleg-tx.signed

echo "Submitting transaction"

container_cli conway transaction submit \
 --tx-file $txs_dir/vote-deleg-tx.signed