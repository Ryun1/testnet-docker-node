#!/bin/bash

set -euo pipefail

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
METADATA_URL="https://raw.githubusercontent.com/Ryun1/metadata/refs/heads/main/cip108/cost-model.jsonld"
METADATA_HASH="a0cb1774a243ee15a83516a2128062127b2d4032ecd290666e1439475dbf846e"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/ga"
tx_path_stub="$txs_dir/parameter-change"
tx_cert_path="$tx_path_stub.action"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

utils_dir="$project_root/utilities"
guardrails_script_path="$utils_dir/guardrails-script.plutus"

# Get the script's directory
# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

# Helper function to get UTXO with validation
get_utxo() {
  local address=$1
  local utxo_output
  utxo_output=$(cardano_cli conway query utxo --address "$address" --out-file /dev/stdout)
  local utxo
  utxo=$(echo "$utxo_output" | jq -r 'keys[0]')
  if [ -z "$utxo" ] || [ "$utxo" = "null" ]; then
    echo "Error: No UTXO found at address: $address" >&2
    exit 1
  fi
  echo "$utxo"
}


# Building, signing and submitting an parameter change governance action
echo "Creating and submitting parameter change governance action."

echo "Hashing guardrails script"
SCRIPT_HASH=$(cardano_cli hash script --script-file $guardrails_script_path)

echo "Script hash: $SCRIPT_HASH"

echo "Finding the previous Parameter Change to reference"

GOV_STATE=$(cardano_cli conway query gov-state | jq -r '.nextRatifyState.nextEnactState.prevGovActionIds')

PREV_GA_TX_HASH=$(echo "$GOV_STATE" | jq -r '.PParamUpdate.txId')
PREV_GA_INDEX=$(echo "$GOV_STATE" | jq -r '.PParamUpdate.govActionIx')

echo "Previous Protocol Param Change GA: $PREV_GA_TX_HASH#$PREV_GA_INDEX"

cardano_cli conway governance action create-protocol-parameters-update \
  --testnet \
  --governance-action-deposit $(cardano_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit') \
  --deposit-return-stake-verification-key-file $keys_dir/stake.vkey \
  --anchor-url "$METADATA_URL" \
  --anchor-data-hash "$METADATA_HASH" \
  --check-anchor-data \
  --constitution-script-hash $SCRIPT_HASH \
  --cost-model-file "$utils_dir/new-cost-model-collapsed-values.json" \
  --prev-governance-action-tx-id "$PREV_GA_TX_HASH" \
  --prev-governance-action-index "$PREV_GA_INDEX" \
  --out-file "$tx_cert_path"

echo "Building transaction"

cardano_cli conway transaction build \
 --tx-in "$(cardano_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --tx-in-collateral "$(cardano_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --proposal-file "$tx_cert_path" \
 --proposal-script-file $guardrails_script_path \
 --proposal-redeemer-value {} \
 --change-address "$(cat $keys_dir/payment.addr)" \
 --out-file "$tx_unsigned_path"

echo "Signing transaction"

cardano_cli conway transaction sign \
 --tx-body-file "$tx_unsigned_path" \
 --signing-key-file $keys_dir/payment.skey \
 --out-file "$tx_signed_path"

# Submit the transaction
echo "Submitting transaction"

cardano_cli conway transaction submit --tx-file $tx_signed_path
