#!/bin/bash
set -euo pipefail

# Unlock ADA from the ExpMod validator
# CIP-109: Modular Exponentiation (expModInteger)
# The validator checks that expModInteger(3, 5, 7) == 5

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/pv11"
plutus_dir="$project_root/plutus/pv11"
script_file="$plutus_dir/expmod-validator.plutus"

# Check prerequisites
if [ ! -f "$keys_dir/payment.addr" ]; then
  echo "Error: Payment address not found: $keys_dir/payment.addr"
  echo "Please run scripts/generate-keys.sh first"
  exit 1
fi

if [ ! -f "$keys_dir/payment.skey" ]; then
  echo "Error: Payment signing key not found: $keys_dir/payment.skey"
  exit 1
fi

if [ ! -f "$script_file" ]; then
  echo "Error: ExpMod validator not found: $script_file"
  echo "Run scalus/compile.sh to compile validators first."
  exit 1
fi

# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

echo -e "${CYAN}=== Unlock ADA from ExpMod Validator (CIP-109) ===${NC}"

# Build script address
SCRIPT_ADDR=$(cardano_cli conway address build --payment-script-file "$script_file")
echo -e "Script address: ${GREEN}$SCRIPT_ADDR${NC}"

# Query script UTxO
echo "Querying script UTxOs..."
SCRIPT_UTXO=$(cardano_cli conway query utxo --address "$SCRIPT_ADDR" --out-file /dev/stdout | jq -r 'keys[0]')

if [ -z "$SCRIPT_UTXO" ] || [ "$SCRIPT_UTXO" = "null" ]; then
  echo "Error: No UTxO found at script address: $SCRIPT_ADDR"
  echo "Run lock-expmod.sh first to lock ADA at the script."
  exit 1
fi
echo "Script UTxO: $SCRIPT_UTXO"

# Get collateral UTxO from payment address
PAYMENT_ADDR=$(cat "$keys_dir/payment.addr")
COLLATERAL_UTXO=$(cardano_cli conway query utxo --address "$PAYMENT_ADDR" --out-file /dev/stdout | jq -r 'keys[0]')

if [ -z "$COLLATERAL_UTXO" ] || [ "$COLLATERAL_UTXO" = "null" ]; then
  echo "Error: No UTxO found for collateral at: $PAYMENT_ADDR"
  exit 1
fi
echo "Collateral UTxO: $COLLATERAL_UTXO"

# Write redeemer (unit / empty constructor)
redeemer_file="$txs_dir/expmod-redeemer.json"
cat > "$redeemer_file" << 'EOF'
{"constructor":0,"fields":[]}
EOF

# Build transaction
echo "Building transaction..."
cardano_cli conway transaction build \
  --tx-in "$SCRIPT_UTXO" \
  --tx-in-script-file "$script_file" \
  --tx-in-inline-datum-present \
  --tx-in-redeemer-file "$redeemer_file" \
  --tx-in-collateral "$COLLATERAL_UTXO" \
  --change-address "$PAYMENT_ADDR" \
  --out-file "$txs_dir/unlock-expmod.unsigned"

# Sign transaction
echo "Signing transaction..."
cardano_cli conway transaction sign \
  --tx-body-file "$txs_dir/unlock-expmod.unsigned" \
  --signing-key-file "$keys_dir/payment.skey" \
  --out-file "$txs_dir/unlock-expmod.signed"

# Submit transaction
echo "Submitting transaction..."
cardano_cli conway transaction submit --tx-file "$txs_dir/unlock-expmod.signed"

echo -e "${GREEN}Success!${NC} Unlocked ADA from ExpMod validator."
echo "The on-chain expModInteger(3, 5, 7) == 5 check passed!"
