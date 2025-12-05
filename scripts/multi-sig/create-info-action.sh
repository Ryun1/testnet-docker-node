#!/bin/bash
set -euo pipefail

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
METADATA_URL="https://buy-ryan-an-island.com"
METADATA_HASH="0000000000000000000000000000000000000000000000000000000000000000"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/multi-sig"
tx_path_stub="$txs_dir/info-action"
tx_cert_path="$tx_path_stub.action"
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

if [ ! -f "$keys_dir/stake.vkey" ]; then
  echo "Error: Stake verification key not found: $keys_dir/stake.vkey"
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

# Building, signing and submitting an info governance action
echo "Creating and submitting info governance action, using the multi-sig's ada."


cardano_cli conway governance action create-info \
  --governance-action-deposit $(cardano_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit') \
  --deposit-return-stake-verification-key-file $keys_dir/stake.vkey \
  --anchor-url "$METADATA_URL" \
  --anchor-data-hash "$METADATA_HASH" \
  --out-file "$tx_cert_path"

# Check certificate file was created
if [ ! -f "$tx_cert_path" ]; then
  echo "Error: Failed to create certificate file"
  exit 1
fi

echo "Building transaction"


cardano_cli conway transaction build \
 --tx-in "$(cardano_cli conway query utxo --address "$(cat $keys_dir/multi-sig/script.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --tx-in-script-file $keys_dir/multi-sig/script.json \
 --tx-in "$(cardano_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --change-address "$(cat $keys_dir/payment.addr)" \
 --proposal-file "$tx_cert_path" \
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
