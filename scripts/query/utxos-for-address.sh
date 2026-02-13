#!/bin/bash
set -euo pipefail

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
ADDRESS="addr_test1wqyr40te8gk6yj05j7x9vhl2ylwrzf83snkhrvzv5medmds6kuhju"
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