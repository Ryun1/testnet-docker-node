#!/bin/bash
set -euo pipefail

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/multi-sig"
tx_path_stub="$txs_dir/one-sig-drep-vote"
tx_cert_path="$tx_path_stub-update.cert"
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

if [ ! -f "$keys_dir/multi-sig/1.skey" ]; then
  echo "Error: Multi-sig signing key 1 not found: $keys_dir/multi-sig/1.skey"
  exit 1
fi

if [ ! -f "$keys_dir/multi-sig/1.keyhash" ]; then
  echo "Error: Multi-sig keyhash 1 not found: $keys_dir/multi-sig/1.keyhash"
  exit 1
fi

if [ ! -f "$txs_dir/drep-one-sig.id" ]; then
  echo "Error: DRep script ID not found: $txs_dir/drep-one-sig.id"
  exit 1
fi

if [ ! -f "$txs_dir/drep-one-sig.json" ]; then
  echo "Error: DRep script JSON not found: $txs_dir/drep-one-sig.json"
  exit 1
fi

if [ ! -f "$txs_dir/metadata.json" ]; then
  echo "Error: Metadata file not found: $txs_dir/metadata.json"
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


echo "Building DRep Update Certificate"

cardano_cli conway governance drep update-certificate \
 --drep-script-hash $(cat $txs_dir/drep-one-sig.id) \
 --out-file $tx_cert_path

echo "Building transaction"

payment_addr=$(cat "$keys_dir/payment.addr")
utxo=$(get_utxo "$payment_addr")


cardano_cli conway transaction build \
 --tx-in $(cardano_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --change-address $(cat $keys_dir/payment.addr) \
 --required-signer-hash "$(cat $keys_dir/multi-sig/1.keyhash)" \
 --certificate-file $tx_cert_path \
 --certificate-script-file $txs_dir/drep-one-sig.json \
 --metadata-json-file $txs_dir/metadata.json \
 --out-file "$tx_unsigned_path"

# Check transaction file was created
if [ ! -f "$tx_unsigned_path" ]; then
  echo "Error: Failed to create unsigned transaction file"
  exit 1
fi

# Create multisig witnesses
cardano_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file "$keys_dir/multi-sig/1.skey" \
  --out-file "$tx_path_stub-1.witness"

# Create witness
cardano_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file "$keys_dir/payment.skey" \
  --out-file "$tx_path_stub-payment.witness"

# Assemble Transaction
cardano_cli conway transaction assemble \
  --tx-body-file "$tx_unsigned_path" \
  --witness-file "$tx_path_stub-payment.witness" \
  --witness-file "$tx_path_stub-1.witness" \
  --out-file "$tx_signed_path"

# Check signed transaction file was created
if [ ! -f "$tx_signed_path" ]; then
  echo "Error: Failed to create signed transaction file"
  exit 1
fi

# Submit the transaction
echo "Submitting transaction"


cardano_cli conway transaction submit --tx-file $tx_signed_path
