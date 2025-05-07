#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
PREV_GA_TX_HASH=""
PREV_GA_INDEX="0"

NEW_MEMBER_CRED="xxx"

METADATA_URL="https://raw.githubusercontent.com/Ryun1/metadata/refs/heads/main/new-const-2"
METADATA_HASH="01318fd6815453f35a4daac80cbbe3bf46c35dc070eb7dc817f26dfee5042eb8"
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

# Building, signing and submitting an new-committee change governance action
echo "Creating and submitting new-committee governance action."

container_cli conway governance action create\
  --testnet \
  --governance-action-deposit $(container_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit') \
  --deposit-return-stake-verification-key-file $keys_dir/stake.vkey \
  --anchor-url "$METADATA_URL" \
  --anchor-data-hash "$METADATA_HASH" \
  --check-anchor-data \
  --out-file $txs_dir/new-committee.action

  # --prev-governance-action-tx-id "$PREV_GA_TX_HASH" \
  # --prev-governance-action-index "$PREV_GA_INDEX" \

echo "Building transaction"

container_cli conway transaction build \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[1]')" \
 --tx-in-collateral "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[1]')" \
 --proposal-file $txs_dir/new-committee.action \
 --change-address "$(cat $keys_dir/payment.addr)" \
 --out-file $txs_dir/new-committee-action-tx.unsigned

echo "Signing transaction"

container_cli conway transaction sign \
 --tx-body-file $txs_dir/new-committee-action-tx.unsigned \
 --signing-key-file $keys_dir/payment.skey \
 --out-file $txs_dir/new-committee-action-tx.signed

echo "Submitting transaction"

container_cli conway transaction submit \
 --tx-file $txs_dir/new-committee-action-tx.signed
