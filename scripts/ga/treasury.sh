#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
LOVELACE_AMOUNT="100000000"

PREV_GA_TX_HASH="0f19207eb4fdb7c538549588ad0a17c577df797ba5d9f1b51658501485ca30b8"
PREV_GA_INDEX="0"

METADATA_URL="https://raw.githubusercontent.com/Ryun1/metadata/refs/heads/main/cip108/treasury-withdrawal.jsonld"
METADATA_HASH="633e6f25fea857662d1542921f1fa2cab5f90a9e4cb51bdae8946f823e403ea8"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directory paths
keys_dir="./keys"
txs_dir="./txs/ga"
tx_path_stub="$txs_dir/treasury-withdrawal"
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

# Building, signing and submitting an treasury governance action
echo "Creating and submitting treasury withdrawal governance action."

echo "\nPull the latest guardrails script."
curl --silent -J -L https://book.world.dev.cardano.org/environments/mainnet/guardrails-script.plutus -o $txs_dir/guardrails-script.plutus

# echo "\nGet the guardrails script hash from the genesis file."
SCRIPT_HASH=$(jq -r ".constitution.script" "./node/config/conway-genesis.json")
echo "Script hash: $SCRIPT_HASH"

container_cli conway governance action create-treasury-withdrawal \
  --testnet \
  --governance-action-deposit $(container_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit') \
  --deposit-return-stake-verification-key-file $keys_dir/stake.vkey \
  --anchor-url "$METADATA_URL" \
  --anchor-data-hash "$METADATA_HASH" \
  --check-anchor-data \
  --funds-receiving-stake-verification-key-file $keys_dir/stake.vkey \
  --transfer $LOVELACE_AMOUNT \
  --constitution-script-hash $SCRIPT_HASH \
  --out-file "$tx_cert_path"

echo "Building the transaction."

echo "Building transaction"

container_cli conway transaction build \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --tx-in-collateral "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --proposal-file "$tx_cert_path" \
 --proposal-script-file $txs_dir/guardrails-script.plutus \
 --proposal-redeemer-value {} \
 --change-address "$(cat $keys_dir/payment.addr)" \
 --out-file "$tx_unsigned_path" \

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
