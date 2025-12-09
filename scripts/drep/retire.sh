#!/bin/bash
set -euo pipefail

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/drep"
tx_path_stub="$txs_dir/drep-retire-tx"
tx_cert_path="$tx_path_stub.cert"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

# Check required files exist
if [ ! -f "$keys_dir/drep.id" ]; then
  echo "Error: DRep ID file not found: $keys_dir/drep.id"
  echo "Please run scripts/generate-keys.sh first"
  exit 1
fi

if [ ! -f "$keys_dir/payment.addr" ]; then
  echo "Error: Payment address file not found: $keys_dir/payment.addr"
  echo "Please run scripts/generate-keys.sh first"
  exit 1
fi

if [ ! -f "$keys_dir/payment.skey" ]; then
  echo "Error: Payment signing key not found: $keys_dir/payment.skey"
  exit 1
fi

if [ ! -f "$keys_dir/drep.skey" ]; then
  echo "Error: DRep signing key not found: $keys_dir/drep.skey"
  exit 1
fi

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


# Retiring you as a drep
echo "Retiring you as a DRep."

cardano_cli conway governance drep retirement-certificate \
 --drep-key-hash $(cat $keys_dir/drep.id) \
 --deposit-amt $(cardano_cli conway query gov-state | jq -r .currentPParams.dRepDeposit) \
 --out-file $tx_cert_path

echo "Building transaction"

cardano_cli conway transaction build \
 --witness-override 2 \
 --tx-in $(cardano_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --change-address $(cat $keys_dir/payment.addr) \
 --certificate-file $tx_cert_path \
 --out-file $tx_unsigned_path

echo "Signing transaction"

cardano_cli conway transaction sign \
 --tx-body-file $tx_unsigned_path \
 --signing-key-file $keys_dir/payment.skey \
 --signing-key-file $keys_dir/drep.skey \
 --out-file $tx_signed_path

# Submit the transaction
echo "Submitting transaction"

cardano_cli conway transaction submit --tx-file $tx_signed_path
