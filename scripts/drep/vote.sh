#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~

CHOICE="yes"
GA_TX_HASH="66cbbf693a8549d0abb1b5219f1127f8176a4052ef774c11a52ff18ad1845102"
GA_TX_INDEX="0"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directory paths
keys_dir="./keys"
txs_dir="./txs/drep"
tx_path_stub="$txs_dir/drep-vote-tx"
tx_cert_path="$tx_path_stub.vote"
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

# Voting on a governance action
echo "Voting on $GA_TX_HASH with a $CHOICE."

container_cli conway governance vote create \
  "--$CHOICE" \
  --governance-action-tx-id "$GA_TX_HASH" \
  --governance-action-index "$GA_TX_INDEX" \
  --drep-verification-key-file $keys_dir/drep.vkey \
  --out-file $tx_cert_path

echo "Building transaction"

container_cli conway transaction build \
  --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
  --change-address "$(cat $keys_dir/payment.addr)" \
  --vote-file $tx_cert_path \
  --witness-override 2 \
  --out-file $tx_unsigned_path

echo "Signing transaction"

container_cli conway transaction sign \
  --tx-body-file $tx_unsigned_path \
  --signing-key-file $keys_dir/drep.skey \
  --signing-key-file $keys_dir/payment.skey \
  --out-file $signed_path

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
