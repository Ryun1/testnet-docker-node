#!/bin/bash
set -euo pipefail

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~

METADATA_URL="ipfs://bafkreihmmaxya6rwrnh36zfl4eaijv67oamdxbj6r3z3nfbwmn55sj4ime"
METADATA_HASH="2df56fcaaa6d6bd73e792b871b746cd9c6209e95a2f0e6344502be9f7abf5567"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/ga"
tx_path_stub="$txs_dir/info"
tx_cert_path="$tx_path_stub.action"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

# Check required files exist
if [ ! -f "$keys_dir/payment.addr" ]; then
  echo "Error: Payment address file not found: $keys_dir/payment.addr"
  echo "Please run scripts/generate-keys.sh first"
  exit 1
fi

if [ ! -f "$keys_dir/payment.skey" ]; then
  echo "Error: Payment signing key not found: $keys_dir/payment.skey"
  exit 1
fi

if [ ! -f "$keys_dir/stake.vkey" ]; then
  echo "Error: Stake verification key not found: $keys_dir/stake.vkey"
  exit 1
fi

# Get the container name from the get-container script
container_name="$("$script_dir/../helper/get-container.sh")"

if [ -z "$container_name" ]; then
  echo "Failed to determine a running container."
  exit 1
fi

echo "Using running container: $container_name"

# Function to execute cardano-cli commands inside the container
container_cli() {
  docker exec -ti "$container_name" cardano-cli "$@"
}

# Helper function to get UTXO with validation
get_utxo() {
  local address=$1
  local utxo_output
  utxo_output=$(container_cli conway query utxo --address "$address" --out-file /dev/stdout)
  local utxo
  utxo=$(echo "$utxo_output" | jq -r 'keys[0]')
  if [ -z "$utxo" ] || [ "$utxo" = "null" ]; then
    echo "Error: No UTXO found at address: $address" >&2
    exit 1
  fi
  echo "$utxo"
}

# Building, signing and submitting an info governance action
echo "Creating and submitting info governance action."

container_cli conway governance action create-info \
  --testnet \
  --governance-action-deposit "$(container_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit')" \
  --deposit-return-stake-verification-key-file "$keys_dir/stake.vkey" \
  --anchor-url "$METADATA_URL" \
  --anchor-data-hash "$METADATA_HASH" \
  --check-anchor-data \
  --out-file "$tx_cert_path"

# Check certificate file was created
if [ ! -f "$tx_cert_path" ]; then
  echo "Error: Failed to create certificate file"
  exit 1
fi

echo "Building transaction"

payment_addr=$(cat "$keys_dir/payment.addr")
utxo=$(get_utxo "$payment_addr")

container_cli conway transaction build \
 --tx-in "$utxo" \
 --change-address "$payment_addr" \
 --proposal-file "$tx_cert_path" \
 --out-file "$tx_unsigned_path"

# Check transaction file was created
if [ ! -f "$tx_unsigned_path" ]; then
  echo "Error: Failed to create unsigned transaction file"
  exit 1
fi

echo "Signing transaction"

container_cli conway transaction sign \
 --tx-body-file "$tx_unsigned_path" \
 --signing-key-file "$keys_dir/payment.skey" \
 --out-file "$tx_signed_path"

# Check signed transaction file was created
if [ ! -f "$tx_signed_path" ]; then
  echo "Error: Failed to create signed transaction file"
  exit 1
fi

# Submit the transaction
echo "Submitting transaction"

container_cli conway transaction submit --tx-file "$tx_signed_path"
