#!/bin/bash
set -euo pipefail

# Lock ADA at the Array validator script address
# CIP-138: Array Type (listToArray, indexArray)
# Test case: Array [10, 20, 30, 40, 50], index 2, expect 30

LOVELACE_AMOUNT=5000000  # 5 ADA

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/pv11"
plutus_dir="$project_root/plutus/pv11"
script_file="$plutus_dir/array-validator.plutus"

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
  echo "Error: Array validator not found: $script_file"
  echo "Run scalus/compile.sh to compile validators first."
  exit 1
fi

# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

# Write datum: list of integers [10, 20, 30, 40, 50]
datum_file="$txs_dir/array-datum.json"
cat > "$datum_file" << 'EOF'
{"list":[{"int":10},{"int":20},{"int":30},{"int":40},{"int":50}]}
EOF

echo -e "${CYAN}=== Lock ADA at Array Validator (CIP-138) ===${NC}"
echo "Test case: Array [10, 20, 30, 40, 50]"
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
  --out-file "$txs_dir/lock-array.unsigned"

# Sign transaction
echo "Signing transaction..."
cardano_cli conway transaction sign \
  --tx-body-file "$txs_dir/lock-array.unsigned" \
  --signing-key-file "$keys_dir/payment.skey" \
  --out-file "$txs_dir/lock-array.signed"

# Submit transaction
echo "Submitting transaction..."
cardano_cli conway transaction submit --tx-file "$txs_dir/lock-array.signed"

echo -e "${GREEN}Success!${NC} Locked $LOVELACE_AMOUNT lovelace at Array validator."
echo "Script address: $SCRIPT_ADDR"
