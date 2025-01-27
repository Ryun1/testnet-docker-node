#!/bin/sh

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~

METADATA_URL="https://raw.githubusercontent.com/Ryun1/metadata/refs/heads/main/secp256r1.jsonld"
METADATA_HASH="40375637aadfdea454726d5f2692b4a940a4d2f2213739a40f9c2560c7bc4239"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Set IPFS gateway incase anchor is using IPFS
export IPFS_GATEWAY_URI="https://ipfs.io/ipfs/"

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

# Building, signing and submitting an info governance action
echo "Creating and submitting info governance action."

container_cli conway governance action create-info \
  --testnet \
  --governance-action-deposit $(container_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit') \
  --deposit-return-stake-verification-key-file $keys_dir/stake.vkey \
  --anchor-url $METADATA_URL \
  --anchor-data-hash $METADATA_HASH \
  --check-anchor-data \
  --out-file $txs_dir/info.action

echo "Building transaction"

container_cli conway transaction build \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --change-address "$(cat $keys_dir/payment.addr)" \
 --proposal-file $txs_dir/info.action \
 --out-file $txs_dir/info-action-tx.unsigned

echo "Signing transaction"

container_cli conway transaction sign \
 --tx-body-file $txs_dir/info-action-tx.unsigned \
 --signing-key-file $keys_dir/payment.skey \
 --out-file $txs_dir/info-action-tx.signed

echo "Submitting transaction"

container_cli conway transaction submit \
 --tx-file $txs_dir/info-action-tx.signed
