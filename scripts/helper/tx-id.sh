#!/bin/bash
set -euo pipefail

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
TRANSACTION_FILE="stake/vote-deleg.signed"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  # Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs"

tx_path="$txs_dir/$TRANSACTION_FILE"

# Check required files exist
if [ ! -f "$tx_path" ]; then
  echo "Error: Transaction file not found: $tx_path"
  exit 1
fi

if [ ! -f "$keys_dir/payment.skey" ]; then
  echo "Error: Payment signing key not found: $keys_dir/payment.skey"
  exit 1
fi

# Source the cardano-cli wrapper
source "$script_dir/cardano-cli-wrapper.sh"

# Send ada to the multisig payment script
echo "Signing and submitting $tx_path transaction."

cardano_cli conway transaction txid --tx-file "$tx_path"
