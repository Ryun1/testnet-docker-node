#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
METADATA_URL="ipfs://bafkreie7nigppy74jyjoibe5ovxy2wulrnk7pn6iocpyrpdhbwtec6mufi"
METADATA_HASH="281f512aff1ab91a0ed3207d3f7a03e55f9dc179cb0f6f3c9ffaf9743dd11e8d"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directory paths
keys_dir="./keys"
txs_dir="./txs/ga"
tx_path_stub="$txs_dir/parameter-change"
tx_cert_path="$tx_path_stub.action"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

guardrails_script_path="./config/guardrails-script.plutus"

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

# Building, signing and submitting an parameter change governance action
echo "Creating and submitting parameter change governance action."

echo "Hashing guardrails script"
SCRIPT_HASH=$(container_cli hash script --script-file $guardrails_script_path)

echo "Script hash: $SCRIPT_HASH"

echo "Finding the previous Parameter Change to reference"

GOV_STATE=$(container_cli conway query gov-state | jq -r '.nextRatifyState.nextEnactState.prevGovActionIds')

PREV_GA_TX_HASH=$(echo "$GOV_STATE" | jq -r '.PParamUpdate.txId')
PREV_GA_INDEX=$(echo "$GOV_STATE" | jq -r '.PParamUpdate.govActionIx')

echo "Previous Protocol Param Change GA: $PREV_GA_TX_HASH#$PREV_GA_INDEX"

container_cli conway governance action create-protocol-parameters-update \
  --testnet \
  --governance-action-deposit $(container_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit') \
  --deposit-return-stake-verification-key-file $keys_dir/stake.vkey \
  --anchor-url "$METADATA_URL" \
  --anchor-data-hash "$METADATA_HASH" \
  --check-anchor-data \
  --constitution-script-hash $SCRIPT_HASH \
  --max-tx-execution-units "(10000000000, 16500000)" \
  --max-block-execution-units "(20000000000, 72000000)" \
  --prev-governance-action-tx-id "$PREV_GA_TX_HASH" \
  --prev-governance-action-index "$PREV_GA_INDEX" \
  --out-file "$tx_cert_path"

echo "Building transaction"

container_cli conway transaction build \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --tx-in-collateral "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --proposal-file "$tx_cert_path" \
 --proposal-script-file $guardrails_script_path \
 --proposal-redeemer-value {} \
 --change-address "$(cat $keys_dir/payment.addr)" \
 --out-file "$tx_unsigned_path"

echo "Signing transaction"

container_cli conway transaction sign \
 --tx-body-file "$tx_unsigned_path" \
 --signing-key-file $keys_dir/payment.skey \
 --out-file "$tx_signed_path"

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
