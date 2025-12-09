#!/bin/bash
set -euo pipefail

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"

# Create keys directory if it doesn't exist
mkdir -p "$keys_dir"

# Source the cardano-cli wrapper
source "$script_dir/helper/cardano-cli-wrapper.sh"

# Check network for mainnet warning (only in Docker mode)
if [ "$NODE_MODE" = "docker" ]; then
  container_name="$("$script_dir/helper/get-container.sh")"
  network=$(echo $container_name | cut -d'-' -f2)
  
  if [ "$network" = "mainnet" ]; then
    echo "These scripts are not secure and should not be used to create mainnet transactions!!"
    echo "Exiting."
    exit 0
  fi
fi

# Check if keys already exist
if [ -f "$keys_dir/drep.id" ]; then
  echo "Keys already generated."
  echo "Exiting."
  exit 0
fi

# Generate keys; payment, stake and DRep.
echo "Generating keys; payment, stake and DRep."
echo "from keys, generate payment address, stake address and DRep ID."

# Generate payment keys
cardano_cli address key-gen \
 --verification-key-file "$keys_dir/payment.vkey" \
 --signing-key-file "$keys_dir/payment.skey"

# Generate stake keys
cardano_cli stake-address key-gen \
 --verification-key-file "$keys_dir/stake.vkey" \
 --signing-key-file "$keys_dir/stake.skey"

# Generate DRep keys
cardano_cli conway governance drep key-gen \
 --verification-key-file "$keys_dir/drep.vkey" \
 --signing-key-file "$keys_dir/drep.skey"

# Generate DRep ID
cardano_cli conway governance drep id \
 --drep-verification-key-file "$keys_dir/drep.vkey" \
 --out-file "$keys_dir/drep.id"

# Get payment address from keys
cardano_cli address build \
 --payment-verification-key-file "$keys_dir/payment.vkey" \
 --stake-verification-key-file "$keys_dir/stake.vkey" \
 --out-file "$keys_dir/payment.addr"

# Derive stake address from stake keys
cardano_cli stake-address build \
 --stake-verification-key-file "$keys_dir/stake.vkey" \
 --out-file "$keys_dir/stake.addr"