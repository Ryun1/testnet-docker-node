#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
PROTOCOL_MAJOR_VERSION="11"
PROTOCOL_MINOR_VERSION="0"

METADATA_URL="https://raw.githubusercontent.com/IntersectMBO/governance-actions/refs/heads/main/mainnet/2024-10-30-hf10/metadata.jsonld"
METADATA_HASH="8a1bd37caa6b914a8b569adb63a0f41d8f159c110dc5c8409118a3f087fffb43"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/ga"
tx_path_stub="$txs_dir/hardfork"
tx_cert_path="$tx_path_stub.action"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

# Get the script's directory
# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

echo "Finding the previous Hardfork to reference"

GOV_STATE=$(cardano_cli conway query gov-state | jq -r '.nextRatifyState.nextEnactState.prevGovActionIds')

PREV_GA_TX_HASH=$(echo "$GOV_STATE" | jq -r '.HardFork.txId')
PREV_GA_INDEX=$(echo "$GOV_STATE" | jq -r '.HardFork.govActionIx')

echo "Previous Hardfork GA: $PREV_GA_TX_HASH#$PREV_GA_INDEX"

# Building, signing and submitting an hardfork change governance action
echo "Creating and submitting hardfork governance action."

cardano_cli conway governance action create-hardfork \
  --governance-action-deposit $(cardano_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit') \
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

cardano_cli conway transaction build \
 --tx-in "$(cardano_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --proposal-file "$tx_cert_path" \
 --change-address "$(cat $keys_dir/payment.addr)" \
 --out-file "$tx_unsigned_path"

echo "Signing transaction"

cardano_cli conway transaction sign \
 --tx-body-file "$tx_unsigned_path" \
 --signing-key-file $keys_dir/payment.skey \
 --out-file "$tx_signed_path"

# Submit the transaction
echo "Submitting transaction"

# cardano_cli conway transaction submit --tx-file $tx_signed_path
