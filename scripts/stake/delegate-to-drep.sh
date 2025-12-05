#!/bin/bash
set -euo pipefail

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
drep_id="3f3d4a84b800b34eb84c6151a955cdd823a0b99e3b886c725b8769e5" # keyhash of the drep
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/stake"
tx_path_stub="$txs_dir/vote-deleg"
tx_cert_path="$tx_path_stub.cert"
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

if [ ! -f "$keys_dir/stake.skey" ]; then
  echo "Error: Stake signing key not found: $keys_dir/stake.skey"
  exit 1
fi


# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

# Delegating to an DRep
echo "Delegating you to DRep: $drep_id."


cardano_cli conway stake-address vote-delegation-certificate \
 --stake-verification-key-file $keys_dir/stake.vkey \
 --drep-key-hash "$drep_id" \
 --out-file "$tx_cert_path"

# Check certificate file was created
if [ ! -f "$tx_cert_path" ]; then
  echo "Error: Failed to create certificate file"
  exit 1
fi

echo "Building transaction"


cardano_cli conway transaction build \
 --witness-override 2 \
 --tx-in $(cardano_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --change-address $(cat $keys_dir/payment.addr) \
 --certificate-file "$tx_cert_path" \
 --out-file "$tx_unsigned_path"

# Check transaction file was created
if [ ! -f "$tx_unsigned_path" ]; then
  echo "Error: Failed to create unsigned transaction file"
  exit 1
fi

echo "Signing transaction"

cardano_cli conway transaction sign \
 --tx-body-file "$tx_unsigned_path" \
 --signing-key-file "$keys_dir/payment.skey" \
 --signing-key-file "$keys_dir/stake.skey" \
 --out-file "$tx_signed_path"

# Check signed transaction file was created
if [ ! -f "$tx_signed_path" ]; then
  echo "Error: Failed to create signed transaction file"
  exit 1
fi

# Submit the transaction
echo "Submitting transaction"


cardano_cli conway transaction submit --tx-file $tx_signed_path
