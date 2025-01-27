#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~

CHOICE="yes"
GA_TX_HASH="66cbbf693a8549d0abb1b5219f1127f8176a4052ef774c11a52ff18ad1845102"
GA_TX_INDEX="0"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directories
keys_dir="./keys"
txs_dir="./txs/drep"

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

# Voting on a governance action
echo "Voting on $GA_TX_HASH with a $CHOICE."

container_cli conway governance vote create \
  "--$CHOICE" \
  --governance-action-tx-id "$GA_TX_HASH" \
  --governance-action-index "$GA_TX_INDEX" \
  --drep-verification-key-file $keys_dir/drep.vkey \
  --out-file $txs_dir/ga.vote

echo "Building transaction"

container_cli conway transaction build \
  --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
  --change-address "$(cat $keys_dir/payment.addr)" \
  --vote-file $txs_dir/ga.vote \
  --witness-override 2 \
  --out-file $txs_dir/vote-tx.unsigned

container_cli conway transaction sign \
  --tx-body-file $txs_dir/vote-tx.unsigned \
  --signing-key-file $keys_dir/drep.skey \
  --signing-key-file $keys_dir/payment.skey \
  --out-file $txs_dir/vote-tx.signed

container_cli conway transaction submit --tx-file $txs_dir/vote-tx.signed
