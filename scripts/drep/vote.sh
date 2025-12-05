#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~

CHOICE="no"
GA_TX_HASH="00b4ff8891a1a697fb917f5f4c865133bdaad856e7e0cda11a886aa6873bea91"
GA_TX_INDEX="0"

ANCHOR_URI="https://raw.githubusercontent.com/Ryun1/metadata/refs/heads/main/sancho-vote.json"
ANCHOR_HASH="5c783d31732ab3661a17879a41b0fd482a0d0befc63e7735641f7c82ba88f00e"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/drep"
tx_path_stub="$txs_dir/drep-vote-tx"
tx_cert_path="$tx_path_stub.vote"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

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
  --anchor-data-hash "$ANCHOR_HASH" \
  --anchor-url "$ANCHOR_URI" \
  --check-anchor-data-hash \
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
  --out-file $tx_signed_path

# Submit the transaction
echo "Submitting transaction"

container_cli conway transaction submit --tx-file $tx_signed_path
