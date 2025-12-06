#!/bin/bash

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/cc"
tx_path_stub="$txs_dir/auth-hot"
tx_cert_path="$tx_path_stub.cert"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

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


echo "Authorizing hot key for the constitutional committee."

cardano_cli conway governance committee create-hot-key-authorization-certificate \
  --cold-verification-key-file "$keys_dir/cc-cold.vkey" \
  --hot-key-file "$keys_dir/cc-hot.vkey" \
  --out-file "$tx_cert_path"

echo "Building transaction"

cardano_cli conway transaction build \
  --witness-override 2 \
  --tx-in $(cardano_cli conway query utxo --address $(cat "$keys_dir/payment.addr") --out-file /dev/stdout | jq -r 'keys[0]') \
  --change-address $(cat "$keys_dir/payment.addr") \
  --certificate-file "$tx_cert_path" \
  --out-file "$tx_unsigned_path"

echo "Signing transaction"

cardano_cli conway transaction sign \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file "$keys_dir/payment.skey" \
  --signing-key-file "$keys_dir/cc-cold.skey" \
  --out-file "$tx_signed_path"

# Submit the transaction
echo "Submitting transaction"

cardano_cli conway transaction submit --tx-file $tx_signed_path