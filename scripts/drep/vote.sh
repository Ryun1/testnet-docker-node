#!/bin/bash
set -euo pipefail

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~

CHOICE="no"
GA_TX_HASH="00b4ff8891a1a697fb917f5f4c865133bdaad856e7e0cda11a886aa6873bea91"
GA_TX_INDEX="0"

ANCHOR_URI="https://raw.githubusercontent.com/Ryun1/metadata/refs/heads/main/sancho-vote.json"
ANCHOR_HASH="5c783d31732ab3661a17879a41b0fd482a0d0befc63e7735641f7c82ba88f00e"

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/drep"
tx_path_stub="$txs_dir/drep-vote-tx"
tx_cert_path="$tx_path_stub.vote"
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

if [ ! -f "$keys_dir/drep.vkey" ]; then
  echo "Error: DRep verification key not found: $keys_dir/drep.vkey"
  exit 1
fi

if [ ! -f "$keys_dir/drep.skey" ]; then
  echo "Error: DRep signing key not found: $keys_dir/drep.skey"
  exit 1
fi

# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

# Voting on a governance action
echo "Voting on $GA_TX_HASH with a $CHOICE."

cardano_cli conway governance vote create \
  "--$CHOICE" \
  --governance-action-tx-id "$GA_TX_HASH" \
  --governance-action-index "$GA_TX_INDEX" \
  --drep-verification-key-file "$keys_dir/drep.vkey" \
  --anchor-data-hash "$ANCHOR_HASH" \
  --anchor-url "$ANCHOR_URI" \
  --check-anchor-data-hash \
  --out-file "$tx_cert_path"

# Check certificate file was created
if [ ! -f "$tx_cert_path" ]; then
  echo "Error: Failed to create certificate file"
  exit 1
fi

echo "Building transaction"

cardano_cli conway transaction build \
  --tx-in "$(cardano_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
  --change-address "$(cat $keys_dir/payment.addr)" \
  --vote-file $tx_cert_path \
  --witness-override 2 \
  --out-file "$tx_unsigned_path"

# Check transaction file was created
if [ ! -f "$tx_unsigned_path" ]; then
  echo "Error: Failed to create unsigned transaction file"
  exit 1
fi

echo "Signing transaction"

cardano_cli conway transaction sign \
  --tx-body-file $tx_unsigned_path \
  --signing-key-file $keys_dir/drep.skey \
  --signing-key-file $keys_dir/payment.skey \
  --out-file $tx_signed_path

# Submit the transaction
echo "Submitting transaction"

cardano_cli conway transaction submit --tx-file $tx_signed_path
