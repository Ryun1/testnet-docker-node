#!/bin/bash
set -euo pipefail

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
LOVELACE_AMOUNT=1000000
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/multi-sig"
tx_path_stub="$txs_dir/send-ada-from-script"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

# Check required files exist
if [ ! -f "$keys_dir/multi-sig/script.addr" ]; then
  echo "Error: Multi-sig script address not found: $keys_dir/multi-sig/script.addr"
  echo "Please run scripts/multi-sig/generate-keys-and-script.sh first"
  exit 1
fi

if [ ! -f "$keys_dir/multi-sig/script.json" ]; then
  echo "Error: Multi-sig script JSON not found: $keys_dir/multi-sig/script.json"
  exit 1
fi

if [ ! -f "$keys_dir/payment.addr" ]; then
  echo "Error: Payment address file not found: $keys_dir/payment.addr"
  echo "Please run scripts/generate-keys.sh first"
  exit 1
fi

for i in 1 2 3; do
  if [ ! -f "$keys_dir/multi-sig/$i.skey" ]; then
    echo "Error: Multi-sig signing key $i not found: $keys_dir/multi-sig/$i.skey"
    exit 1
  fi
  if [ ! -f "$keys_dir/multi-sig/$i.keyhash" ]; then
    echo "Error: Multi-sig keyhash $i not found: $keys_dir/multi-sig/$i.keyhash"
    exit 1
  fi
done

if [ ! -f "$keys_dir/payment.skey" ]; then
  echo "Error: Payment signing key not found: $keys_dir/payment.skey"
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

# Send ada to the multisig payment script
echo "Sending $LOVELACE_AMOUNT lovelace to the payment address from the script."

echo "Building transaction"

script_addr=$(cat "$keys_dir/multi-sig/script.addr")
payment_addr=$(cat "$keys_dir/payment.addr")
script_utxo=$(get_utxo "$script_addr")

container_cli conway transaction build \
 --tx-in "$script_utxo" \
 --tx-in-script-file "$keys_dir/multi-sig/script.json" \
 --tx-out "$payment_addr+$LOVELACE_AMOUNT" \
 --change-address "$script_addr" \
 --required-signer-hash "$(cat "$keys_dir/multi-sig/1.keyhash")" \
 --required-signer-hash "$(cat "$keys_dir/multi-sig/2.keyhash")" \
 --required-signer-hash "$(cat "$keys_dir/multi-sig/3.keyhash")" \
 --out-file "$tx_unsigned_path"

# Check transaction file was created
if [ ! -f "$tx_unsigned_path" ]; then
  echo "Error: Failed to create unsigned transaction file"
  exit 1
fi

# Create multisig witnesses
container_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file "$keys_dir/multi-sig/1.skey" \
  --out-file "$tx_path_stub-1.witness"

container_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file "$keys_dir/multi-sig/2.skey" \
  --out-file "$tx_path_stub-2.witness"

container_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file "$keys_dir/multi-sig/3.skey" \
  --out-file "$tx_path_stub-3.witness"

# Create witness
container_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file "$keys_dir/payment.skey" \
  --out-file "$tx_path_stub-payment.witness"

# Assemble Transaction
container_cli conway transaction assemble \
  --tx-body-file "$tx_unsigned_path" \
  --witness-file "$tx_path_stub-payment.witness" \
  --witness-file "$tx_path_stub-1.witness" \
  --witness-file "$tx_path_stub-2.witness" \
  --witness-file "$tx_path_stub-3.witness" \
  --out-file "$tx_signed_path"

# Check signed transaction file was created
if [ ! -f "$tx_signed_path" ]; then
  echo "Error: Failed to create signed transaction file"
  exit 1
fi

# Submit the transaction
echo "Submitting transaction"

container_cli conway transaction submit --tx-file "$tx_signed_path"
