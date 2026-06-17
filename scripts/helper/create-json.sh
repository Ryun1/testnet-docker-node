#!/bin/bash
set -euo pipefail

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
TRANSACTION_FILE="out-transaction.unsigned"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs"

TRANSACTION_PATH="$txs_dir/$TRANSACTION_FILE"

# Check required files exist
if [ ! -f "$TRANSACTION_PATH" ]; then
  echo "Error: Transaction file not found: $TRANSACTION_PATH"
  exit 1
fi

# Source the cardano-cli wrapper
source "$script_dir/cardano-cli-wrapper.sh"

# Send ada to the multisig payment script
echo "Creating $TRANSACTION_PATH JSON representation at $TRANSACTION_PATH.json."

cardano_cli debug transaction view \
 --tx-file "$TRANSACTION_PATH" \
 --output-json \
 --out-file "$TRANSACTION_PATH.json"
