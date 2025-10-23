#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
PROTOCOL_MAJOR_VERSION="11"
PROTOCOL_MINOR_VERSION="0"

PREV_GA_TX_HASH="fd80ab8f65a620da457c18574787c9e5091bc2c71b776cd5edad0a005c37e307"
PREV_GA_INDEX="0"

METADATA_URL="https://raw.githubusercontent.com/IntersectMBO/governance-actions/refs/heads/main/mainnet/2024-10-30-hf10/metadata.jsonld"
METADATA_HASH="8a1bd37caa6b914a8b569adb63a0f41d8f159c110dc5c8409118a3f087fffb43"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directory paths
keys_dir="./keys"
txs_dir="./txs/ga"
tx_path_stub="$txs_dir/hardfork"
tx_cert_path="$tx_path_stub.action"
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

# Building, signing and submitting an hardfork change governance action
echo "Creating and submitting hardfork governance action."

container_cli conway governance action create-hardfork \
  --testnet \
  --governance-action-deposit $(container_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit') \
  --deposit-return-stake-verification-key-file $keys_dir/stake.vkey \
  --anchor-url "$METADATA_URL" \
  --anchor-data-hash "$METADATA_HASH" \
  --check-anchor-data \
  --protocol-major-version "$PROTOCOL_MAJOR_VERSION" \
  --protocol-minor-version "$PROTOCOL_MINOR_VERSION" \
  --prev-governance-action-tx-id "$PREV_GA_TX_HASH" \
  --prev-governance-action-index "$PREV_GA_INDEX" \
  --out-file "$tx_cert_path"

echo "Building transaction"

container_cli conway transaction build \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --proposal-file "$tx_cert_path" \
 --change-address "$(cat $keys_dir/payment.addr)" \
 --out-file "$txs_unsigned_path"

echo "Signing transaction"

container_cli conway transaction sign \
 --tx-body-file "$txs_unsigned_path" \
 --signing-key-file $keys_dir/payment.skey \
 --out-file "$txs_signed_path"

# Submit the transaction
echo "Submitting transaction"

container_cli conway transaction submit --tx-file $tx_signed_path
