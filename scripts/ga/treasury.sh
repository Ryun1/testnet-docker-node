#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
LOVELACE_AMOUNT="5000000000000"

METADATA_URL="https://raw.githubusercontent.com/Ryun1/metadata/refs/heads/main/EG-0003-25.jsonld"
METADATA_HASH="91a36ac3cc4b563a407e7a86139fee9e7e2b2a6511617b96ba3165ccddf5a5b3"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Exit immediately if a command exits with a non-zero status, 
# treat unset variables as an error, and fail if any command in a pipeline fails
set -euo pipefail

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/ga"
tx_path_stub="$txs_dir/treasury-withdrawal"
tx_cert_path="$tx_path_stub.action"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

guardrails_script_path="./config/guardrails-script.plutus"

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


# Building, signing and submitting an treasury governance action
echo "Creating and submitting treasury withdrawal governance action."

echo "Hashing guardrails script"
SCRIPT_HASH=$(cardano_cli hash script --script-file $guardrails_script_path)

echo "Script hash: $SCRIPT_HASH"

cardano_cli conway governance action create-treasury-withdrawal \
  --governance-action-deposit $(cardano_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit') \
  --deposit-return-stake-verification-key-file $keys_dir/stake.vkey \
  --anchor-url "$METADATA_URL" \
  --anchor-data-hash "$METADATA_HASH" \
  --check-anchor-data \
  --funds-receiving-stake-verification-key-file $keys_dir/stake.vkey \
  --transfer $LOVELACE_AMOUNT \
  --constitution-script-hash $SCRIPT_HASH \
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

echo "Submitting transaction"

cardano_cli conway transaction submit --tx-file $tx_signed_path
