#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
PREV_GA_TX_HASH="fd80ab8f65a620da457c18574787c9e5091bc2c71b776cd5edad0a005c37e307"
PREV_GA_INDEX="0"

METADATA_URL="https://raw.githubusercontent.com/IntersectMBO/governance-actions/refs/heads/main/mainnet/2024-10-30-hf10/metadata.jsonld"
METADATA_HASH="8a1bd37caa6b914a8b569adb63a0f41d8f159c110dc5c8409118a3f087fffb43"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Set IPFS gateway incase anchor is using IPFS
IPFS_GATEWAY_URI="https://ipfs.io/ipfs/"

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

# Building, signing and submitting an hardfork change governance action
echo "Creating and submitting hardfork governance action."

container_cli conway governance action create-hardfork \
  --testnet \
  --governance-action-deposit $(container_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit') \
  --deposit-return-stake-verification-key-file $keys_dir/stake.vkey \
  --anchor-url "$METADATA_URL" \
  --anchor-data-hash "$METADATA_HASH" \
  --check-anchor-data \
  --protocol-major-version 11 \
  --protocol-minor-version 0 \
  --prev-governance-action-tx-id "$PREV_GA_TX_HASH" \
  --prev-governance-action-index "$PREV_GA_INDEX" \
  --out-file $txs_dir/hardfork.action

echo "Building transaction"

container_cli conway transaction build \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[1]')" \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[3]')" \
 --tx-in-collateral "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[1]')" \
 --proposal-file $txs_dir/hardfork.action \
 --change-address "$(cat $keys_dir/payment.addr)" \
 --out-file $txs_dir/hardfork-action-tx.unsigned

echo "Signing transaction"

container_cli conway transaction sign \
 --tx-body-file $txs_dir/hardfork-action-tx.unsigned \
 --signing-key-file $keys_dir/payment.skey \
 --out-file $txs_dir/hardfork-action-tx.signed

echo "Submitting transaction"

container_cli conway transaction submit \
 --tx-file $txs_dir/hardfork-action-tx.signed

