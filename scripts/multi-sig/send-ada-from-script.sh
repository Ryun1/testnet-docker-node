#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
LOVELACE_AMOUNT=1000000
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
echo "Sending $LOVELACE_AMOUNT lovelace to the payment address from the script."

echo "Building transaction"

container_cli conway transaction build \
 --tx-in $(container_cli conway query utxo --address $(cat $keys_dir/multi-sig/script.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --tx-in-script-file $keys_dir/multi-sig/script.json \
 --tx-out $(cat $keys_dir/payment.addr)+$LOVELACE_AMOUNT \
 --change-address $(cat $keys_dir/multi-sig/script.addr) \
 --required-signer-hash "$(cat $keys_dir/multi-sig/1.keyhash)" \
 --required-signer-hash "$(cat $keys_dir/multi-sig/3.keyhash)" \
 --out-file $txs_dir/multi-sig/send-ada-from-script.unsigned

# Create witnesses

# Key 1
container_cli conway transaction witness \
  --tx-body-file $txs_dir/multi-sig/send-ada-from-script.unsigned \
  --signing-key-file $keys_dir/multi-sig/1.skey \
  --out-file $txs_dir/multi-sig/send-ada-from-script-1.witness

# Key 2
# container_cli conway transaction witness \
#   --tx-body-file $txs_dir/multi-sig/send-ada-from-script.unsigned \
#   --signing-key-file $keys_dir/multi-sig/2.skey \
#   --out-file $txs_dir/multi-sig/send-ada-from-script-2.witness

# Key 3
container_cli conway transaction witness \
  --tx-body-file $txs_dir/multi-sig/send-ada-from-script.unsigned \
  --signing-key-file $keys_dir/multi-sig/3.skey \
  --out-file $txs_dir/multi-sig/send-ada-from-script-3.witness

# Assemble transaction
container_cli conway transaction assemble \
  --tx-body-file $txs_dir/multi-sig/send-ada-from-script.unsigned \
  --witness-file $txs_dir/multi-sig/send-ada-from-script-1.witness \
  --witness-file $txs_dir/multi-sig/send-ada-from-script-3.witness \
  --out-file $txs_dir/multi-sig/send-ada-from-script.signed

# Submit transaction
echo "Submitting transaction"

container_cli conway transaction submit \
 --tx-file $txs_dir/multi-sig/send-ada-from-script.signed
