#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
NEW_CONSTITUTION_ANCHOR_URL="ipfs://QmbiATXEFuuAktbjLJJPiRyZowAgqqM3hfZoNFNmMCygjb"
NEW_CONSTITUTION_ANCHOR_HASH="2a61e2f4b63442978140c77a70daab3961b22b12b63b13949a390c097214d1c5"

NEW_CONSTITUTION_SCRIPT_HASH="fa24fb305126805cf2164c161d852a0e7330cf988f1fe558cf7d4a64"

METADATA_URL="https://raw.githubusercontent.com/IntersectMBO/governance-actions/refs/heads/main/preview/2024-12-19-conts/metadata.jsonld"
METADATA_HASH="4b2649556c838497ee2923bdff0f05b48fb2f0c3c5cceb450200f8bd6868ac5b"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/ga"
tx_path_stub="$txs_dir/new-constitution"
tx_cert_path="$tx_path_stub.action"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

# Get the script's directory
# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

echo "Finding the previous Constitution GA to reference"

# GOV_STATE=$(cardano_cli conway query gov-state | jq -r '.nextRatifyState.nextEnactState.prevGovActionIds')

PREV_GA_TX_HASH=$(echo "$GOV_STATE" | jq -r '.Constitution.txId')
PREV_GA_INDEX=$(echo "$GOV_STATE" | jq -r '.Constitution.govActionIx')

echo "Previous Constitution GA Tx Hash: $PREV_GA_TX_HASH#$PREV_GA_INDEX"

# Building, signing and submitting an new-constitution change governance action
echo "Creating and submitting new-constitution governance action."

cardano_cli conway governance action create-constitution \
  --governance-action-deposit $(cardano_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit') \
  --deposit-return-stake-verification-key-file $keys_dir/stake.vkey \
  --anchor-url "$METADATA_URL" \
  --anchor-data-hash "$METADATA_HASH" \
  --check-anchor-data \
  --constitution-url "$NEW_CONSTITUTION_ANCHOR_URL" \
  --constitution-hash "$NEW_CONSTITUTION_ANCHOR_HASH" \
  --check-constitution-hash \
  --constitution-script-hash "$NEW_CONSTITUTION_SCRIPT_HASH" \
  --prev-governance-action-tx-id "$PREV_GA_TX_HASH" \
  --prev-governance-action-index "$PREV_GA_INDEX" \
  --out-file "$tx_cert_path"

echo "Building transaction"

cardano_cli conway transaction build \
 --tx-in "$(cardano_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --proposal-file "$tx_cert_path" \
 --change-address "$(cat $keys_dir/payment.addr)" \
 --out-file "$tx_unsigned_path" \

echo "Signing transaction"

cardano_cli conway transaction sign \
 --tx-body-file "$tx_unsigned_path" \
 --signing-key-file $keys_dir/payment.skey \
 --out-file "$tx_signed_path"

# Submit the transaction
echo "Submitting transaction"

cardano_cli conway transaction submit --tx-file $tx_signed_path
