#!/bin/bash
set -euo pipefail

# Lock ADA at the ExpMod validator script address
# CIP-109: Modular Exponentiation (expModInteger)
# Test case: 3^5 mod 7 = 243 mod 7 = 5

LOVELACE_AMOUNT=5000000  # 5 ADA

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/pv11"
plutus_dir="$project_root/plutus/pv11"
script_file="$plutus_dir/expmod-validator.plutus"

# Create txs directory if needed
mkdir -p "$txs_dir"

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

# Write datum: {base: 3, exponent: 5, modulus: 7, expected: 5}
# 3^5 mod 7 = 243 mod 7 = 5
datum_file="$txs_dir/expmod-datum.json"
cat > "$datum_file" << 'EOF'
{"constructor":0,"fields":[{"int":3},{"int":5},{"int":7},{"int":5}]}
EOF

echo -e "${CYAN}=== Lock ADA at ExpMod Validator (CIP-109) ===${NC}"
echo "Test case: 3^5 mod 7 = 5"
echo "Amount: $LOVELACE_AMOUNT lovelace"

# Build script address
echo "Building script address..."
SCRIPT_ADDR=$(cardano_cli conway address build --payment-script-file "$script_file")
echo -e "Script address: ${GREEN}$SCRIPT_ADDR${NC}"

# Get payment address and UTxO
PAYMENT_ADDR=$(cat "$keys_dir/payment.addr")
echo "Querying UTxOs..."
UTXO=$(cardano_cli conway query utxo --address "$PAYMENT_ADDR" --out-file /dev/stdout | jq -r 'keys[0]')

if [ -z "$UTXO" ] || [ "$UTXO" = "null" ]; then
  echo "Error: No UTxO found at payment address: $PAYMENT_ADDR"
  exit 1
fi
echo "Using UTxO: $UTXO"

# Build transaction
echo "Building transaction..."
cardano_cli conway transaction build \
  --tx-in "$UTXO" \
  --tx-out "$SCRIPT_ADDR+$LOVELACE_AMOUNT" \
  --tx-out-inline-datum-file "$datum_file" \
  --change-address "$PAYMENT_ADDR" \
  --out-file "$txs_dir/lock-expmod.unsigned"

# Sign transaction
echo "Signing transaction..."
cardano_cli conway transaction sign \
  --tx-body-file "$txs_dir/lock-expmod.unsigned" \
  --signing-key-file "$keys_dir/payment.skey" \
  --out-file "$txs_dir/lock-expmod.signed"

# Submit transaction
echo "Submitting transaction..."
cardano_cli conway transaction submit --tx-file "$txs_dir/lock-expmod.signed"

echo -e "${GREEN}Success!${NC} Locked $LOVELACE_AMOUNT lovelace at ExpMod validator."
echo "Script address: $SCRIPT_ADDR"
