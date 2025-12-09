#!/bin/bash
set -euo pipefail

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
ADDRESS="addr_test1wz0vzkrzked85ywpsq4ffmx2etvjtnk07lvldrp3d4ht86ckfg639"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"


# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

echo "Querying UTXOs for address: $ADDRESS"

# Query the UTxOs controlled by the payment address
cardano_cli conway query utxo \
  --address "$ADDRESS" \
  --out-file /dev/stdout