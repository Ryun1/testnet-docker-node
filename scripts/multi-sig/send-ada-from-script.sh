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


# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

# Send ada to the multisig payment script
echo "Sending $LOVELACE_AMOUNT lovelace to the payment address from the script."

echo "Building transaction"


cardano_cli conway transaction build \
 --tx-in $(cardano_cli conway query utxo --address $(cat $keys_dir/multi-sig/script.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --tx-in-script-file $keys_dir/multi-sig/script.json \
 --tx-out $(cat $keys_dir/payment.addr)+$LOVELACE_AMOUNT \
 --change-address $(cat $keys_dir/multi-sig/script.addr) \
 --required-signer-hash "$(cat $keys_dir/multi-sig/1.keyhash)" \
 --required-signer-hash "$(cat $keys_dir/multi-sig/2.keyhash)" \
 --required-signer-hash "$(cat $keys_dir/multi-sig/3.keyhash)" \
 --out-file "$tx_unsigned_path"

# Create multisig witnesses
cardano_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file "$keys_dir/multi-sig/1.skey" \
  --out-file "$tx_path_stub-1.witness"

cardano_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file "$keys_dir/multi-sig/2.skey" \
  --out-file "$tx_path_stub-2.witness"

cardano_cli conway transaction witness \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file "$keys_dir/multi-sig/3.skey" \
  --out-file "$tx_path_stub-3.witness"

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


cardano_cli conway transaction submit --tx-file $tx_signed_path
