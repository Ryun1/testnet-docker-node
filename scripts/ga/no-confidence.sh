#!/bin/sh

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
PREV_GA_TX_HASH=""
PREV_GA_INDEX="0"

METADATA_URL="https://raw.githubusercontent.com/IntersectMBO/governance-actions/refs/heads/main/preview/2024-10-30-hf10/metadata.jsonld"
METADATA_HASH="ab901c3aeeca631ee5c70147a558fbf191a4af245d8ca001e845d8569d7c38f9"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Set IPFS gateway incase anchor is using IPFS
export IPFS_GATEWAY_URI="https://ipfs.io/"

# Define directories
keys_dir="./keys"
txs_dir="$txs_dir/ga"

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

# Building, signing and submitting an no-confidence change governance action
echo "Creating and submitting no-confidence governance action."

container_cli conway governance action create-no-confidence \
  --testnet \
  --governance-action-deposit $(container_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit') \
  --deposit-return-stake-verification-key-file $keys_dir/stake.vkey \
  --anchor-url "$METADATA_URL" \
  --anchor-data-hash "$METADATA_HASH" \
  --check-anchor-data \
  --out-file $txs_dir/no-confidence.action

  # --prev-governance-action-tx-id "$PREV_GA_TX_HASH" \
  # --prev-governance-action-index "$PREV_GA_INDEX" \

echo "Building transaction"

container_cli conway transaction build \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[1]')" \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[3]')" \
 --tx-in-collateral "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[1]')" \
 --proposal-file $txs_dir/no-confidence.action \
 --change-address "$(cat $keys_dir/payment.addr)" \
 --out-file $txs_dir/no-confidence-action-tx.unsigned

echo "Signing transaction"

container_cli conway transaction sign \
 --tx-body-file $txs_dir/no-confidence-action-tx.unsigned \
 --signing-key-file $keys_dir/payment.skey \
 --out-file $txs_dir/no-confidence-action-tx.signed

echo "Submitting transaction"

container_cli conway transaction submit \
 --tx-file $txs_dir/no-confidence-action-tx.signed

