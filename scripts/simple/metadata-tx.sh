#!/bin/bash
set -euo pipefail

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/simple"
tx_path_stub="$txs_dir/metadata-transaction"
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

if [ ! -f "$txs_dir/metadata.json" ]; then
  echo "Error: Metadata file not found: $txs_dir/metadata.json"
  exit 1
fi


# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

echo "Building transaction"

cardano_cli conway transaction build \
 --tx-in $(cardano_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --change-address $(cat $keys_dir/payment.addr) \
 --metadata-json-file "$txs_dir/metadata.json" \
 --out-file "$tx_unsigned_path"

cardano_cli conway transaction sign \
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


cardano_cli conway transaction submit --tx-file $tx_signed_path
