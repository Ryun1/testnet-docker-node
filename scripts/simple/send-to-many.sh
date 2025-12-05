#!/bin/bash
set -euo pipefail

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
LOVELACE_AMOUNT=1230000
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/simple"
CSV_FILE="$keys_dir/addresses-testnet.csv"
METADATA_FILE="$keys_dir/metadata-testnet.json"
tx_path_stub="$txs_dir/send-to-many"
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

# Get the container name from the get-container script
container_name="$("$script_dir/../helper/get-container.sh")"

if [ -z "$container_name" ]; then
  echo "Failed to determine a running container."
  exit 1
fi

echo "Using running container: $container_name"

# Function to execute cardano-cli commands inside the container
container_cli() {
  docker exec -ti "$container_name" cardano-cli "$@"
}

# Helper function to get UTXO with validation
get_utxo() {
  local address=$1
  local utxo_output
  utxo_output=$(container_cli conway query utxo --address "$address" --out-file /dev/stdout)
  local utxo
  utxo=$(echo "$utxo_output" | jq -r 'keys[0]')
  if [ -z "$utxo" ] || [ "$utxo" = "null" ]; then
    echo "Error: No UTXO found at address: $address" >&2
    exit 1
  fi
  echo "$utxo"
}

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
  echo "Error: CSV file not found: $CSV_FILE"
  exit 1
fi

# Verify header contains "address"
if ! head -1 "$CSV_FILE" | grep -q "address"; then
  echo "Error: CSV file must have 'address' column header"
  exit 1
fi

# Read addresses from CSV file (skip header, extract first column)
addresses=()
first_line=true
while IFS=',' read -r addr rest; do
  # Skip header line
  if [ "$first_line" = true ]; then
    first_line=false
    continue
  fi
  # Remove quotes and whitespace
  addr=$(echo "$addr" | sed 's/"//g' | xargs)
  if [ -n "$addr" ]; then
    addresses+=("$addr")
  fi
done < "$CSV_FILE"

# Check if we found any addresses
if [ ${#addresses[@]} -eq 0 ]; then
  echo "Error: No addresses found in CSV file"
  exit 1
fi

echo "Found ${#addresses[@]} addresses in CSV file"
echo "Sending $LOVELACE_AMOUNT lovelace to each address"

# Get UTXO from payment address
payment_addr=$(cat "$keys_dir/payment.addr")
utxo=$(get_utxo "$payment_addr")

echo "Using UTXO: $utxo"

# Build transaction with multiple tx-out entries
echo "Building transaction"

build_args=(
  "conway" "transaction" "build"
  "--tx-in" "$utxo"
)

# Add tx-out for each address
for addr in "${addresses[@]}"; do
  build_args+=("--tx-out" "$addr+$LOVELACE_AMOUNT")
done

# Add change address
build_args+=(
  "--change-address" "$payment_addr"
)

# Add metadata if specified
if [ -n "$METADATA_FILE" ]; then
  if [ -f "$METADATA_FILE" ]; then
    echo "Including metadata from: $METADATA_FILE"
    build_args+=("--metadata-json-file" "$METADATA_FILE")
  else
    echo "Warning: Metadata file not found: $METADATA_FILE"
    echo "Continuing without metadata..."
  fi
fi

build_args+=("--out-file" "$tx_unsigned_path")

container_cli "${build_args[@]}"

# Check transaction file was created
if [ ! -f "$tx_unsigned_path" ]; then
  echo "Error: Failed to create unsigned transaction file"
  exit 1
fi

# Sign the transaction
echo "Signing transaction"

container_cli conway transaction sign \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file "$keys_dir/payment.skey" \
  --out-file "$tx_signed_path"

# Check signed transaction file was created
if [ ! -f "$tx_signed_path" ]; then
  echo "Error: Failed to create signed transaction file"
  exit 1
fi

# Submit the transaction
echo "Submitting transaction"

container_cli conway transaction submit --tx-file "$tx_signed_path"

echo "Transaction submitted successfully!"
echo "Sent $LOVELACE_AMOUNT lovelace to ${#addresses[@]} addresses"

