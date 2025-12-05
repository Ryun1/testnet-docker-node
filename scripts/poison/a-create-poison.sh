#!/bin/bash

# Script to test Hypothesis A: PoolHash bug allows arbitrary lengths of bytes after a valid Poolhash
# This script builds a stake delegation transaction, then allows user to input a poisoned PoolID
# which replaces the original PoolID in the transaction CBOR before signing.

# Get test case number from user
echo "=========================================="
echo "Hypothesis A - PoolHash Poison Test"
echo "=========================================="
echo ""
read -p "Enter test case number: " test_case_number

if [ -z "$test_case_number" ]; then
  echo "Error: Test case number is required."
  exit 1
fi

# Define directory paths
keys_dir="./keys"
txs_dir="./txs/poison"
test_case_dir="$txs_dir/hypothesis-a-poison/$test_case_number"
tx_path_stub="$test_case_dir/poison-tx"
tx_cert_path="$tx_path_stub.cert"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

# Create test case directory if it doesn't exist
mkdir -p "$test_case_dir"

# Get the script's directory
script_dir=$(dirname "$0")

# Get the container name from the get-container script
container_name="$("$script_dir/../helper/get-container.sh")"

if [ -z "$container_name" ]; then
  echo "Failed to determine a running container."
  exit 1
fi

echo "Using running container: $container_name"
echo "Test case number: $test_case_number"
echo "Files will be saved to: $test_case_dir"
echo ""

# Function to execute cardano-cli commands inside the container
container_cli() {
  docker exec -ti $container_name cardano-cli "$@"
}

# Test case directory already created above

# Step 1: Query stake pools and get the first PoolID
echo "Querying stake pools..."
pools_output=$(container_cli conway query stake-pools --out-file /dev/stdout)

if [ -z "$pools_output" ]; then
  echo "Error: No stake pools found. Cannot proceed."
  exit 1
fi

# Extract first PoolID from array
# The output is an array of pool IDs: ["pool1...", "pool1...", ...]
pool_id=$(echo "$pools_output" | jq -r '.[0]' 2>/dev/null)

# Validate we got a real pool ID
if [ -z "$pool_id" ] || [ "$pool_id" = "null" ]; then
  echo "Error: Could not extract valid PoolID from stake pools query."
  echo "Pools output (first 500 chars):"
  echo "$pools_output" | head -c 500
  exit 1
fi

echo "Using PoolID: $pool_id"

# Step 2: Build stake delegation certificate with valid PoolID
echo "Creating stake delegation certificate..."
container_cli conway stake-address stake-delegation-certificate \
  --stake-verification-key-file $keys_dir/stake.vkey \
  --stake-pool-id "$pool_id" \
  --out-file "$tx_cert_path"

if [ ! -f "$tx_cert_path" ]; then
  echo "Error: Failed to create certificate file."
  exit 1
fi

echo "Certificate created: $tx_cert_path"

# Step 3: Build unsigned transaction
echo "Building unsigned transaction..."

# Get UTxO
utxo=$(container_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file /dev/stdout | jq -r 'keys[0]')

if [ -z "$utxo" ] || [ "$utxo" = "null" ]; then
  echo "Error: No UTxO found at payment address: $(cat $keys_dir/payment.addr)"
  exit 1
fi

echo "Using UTxO: $utxo"

container_cli conway transaction build \
  --witness-override 2 \
  --tx-in "$utxo" \
  --change-address $(cat $keys_dir/payment.addr) \
  --certificate-file "$tx_cert_path" \
  --out-file "$tx_unsigned_path"

if [ ! -f "$tx_unsigned_path" ]; then
  echo "Error: Failed to create unsigned transaction file."
  exit 1
fi

echo "Unsigned transaction created: $tx_unsigned_path"

# Step 4: Get user input for poisoned PoolID
echo ""
echo "=========================================="
echo "Transaction built with valid PoolID: $pool_id"
echo "=========================================="
echo ""
echo "Enter the poisoned PoolID to replace the original (as hex string)."
echo "You can provide:"
echo "  - A hex string (e.g., abc123...)"
echo "  - A valid PoolID hex followed by arbitrary hex bytes"
echo "  - Any hex bytes (will be used as-is)"
echo ""
read -p "Enter poisoned PoolID (hex): " poisoned_poolid

if [ -z "$poisoned_poolid" ]; then
  echo "Error: No poisoned PoolID provided."
  exit 1
fi

# Step 5: Manipulate CBOR to replace PoolID
echo ""
echo "Manipulating transaction CBOR to replace PoolID..."

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
  echo "Error: python3 not found. Please install Python 3."
  exit 1
fi

# Check for virtual environment and activate if it exists
venv_dir="./venv"
if [ -d "$venv_dir" ] && [ -f "$venv_dir/bin/activate" ]; then
  echo "Activating virtual environment..."
  source "$venv_dir/bin/activate"
fi

# Check if cbor2 is installed
if ! python3 -c "import cbor2" 2>/dev/null; then
  echo "Error: cbor2 Python library not found."
  echo ""
  echo "Please set up the virtual environment by running:"
  echo "  ./scripts/poison/setup-venv.sh"
  echo ""
  echo "Or install manually:"
  echo "  pip3 install --break-system-packages cbor2 bech32"
  exit 1
fi

# Check if bech32 is installed (needed for decoding original PoolID from query)
if ! python3 -c "import bech32" 2>/dev/null; then
  echo "Warning: bech32 Python library not found."
  echo "Needed for decoding original PoolID (bech32 format from query)."
  echo "Install with: pip install bech32"
  echo "The script will attempt to use cardano-cli as fallback."
fi

# Create a backup of the original transaction
cp "$tx_unsigned_path" "$tx_unsigned_path.backup"

# Run Python script to poison the transaction
# Original PoolID is bech32 (from query), poisoned PoolID is hex (from user)
# Always pass cardano-cli command as fallback for bech32 decoding
python3 "$script_dir/cbor_poison.py" \
  --tx-file "$tx_unsigned_path" \
  --original-poolid "$pool_id" \
  --poisoned-poolid "$poisoned_poolid" \
  --output "$tx_unsigned_path" \
  --cardano-cli "docker exec -i $container_name cardano-cli"

if [ $? -ne 0 ]; then
  echo "Error: Failed to poison transaction CBOR."
  echo "Restoring original transaction from backup..."
  mv "$tx_unsigned_path.backup" "$tx_unsigned_path"
  exit 1
fi

echo "Transaction CBOR successfully modified."

# Step 6: Sign the modified transaction
echo ""
echo "Signing the modified transaction..."

container_cli conway transaction sign \
  --tx-body-file "$tx_unsigned_path" \
  --signing-key-file $keys_dir/payment.skey \
  --signing-key-file $keys_dir/stake.skey \
  --out-file "$tx_signed_path"

if [ ! -f "$tx_signed_path" ]; then
  echo "Error: Failed to sign transaction."
  exit 1
fi

echo "Transaction signed: $tx_signed_path"

# Step 7: Prompt for submission
echo ""
echo "=========================================="
echo "Transaction ready for submission"
echo "=========================================="
echo ""
echo "Original PoolID: $pool_id"
echo "Poisoned PoolID: $poisoned_poolid"
echo ""
read -p "Do you want to submit this transaction? (y/n): " submit_choice

if [ "$submit_choice" = "y" ] || [ "$submit_choice" = "Y" ]; then
  echo ""
  echo "Submitting transaction..."
  container_cli conway transaction submit --tx-file "$tx_signed_path"
  
  if [ $? -eq 0 ]; then
    echo "Transaction submitted successfully!"
    echo "Transaction file: $tx_signed_path"
  else
    echo "Error: Failed to submit transaction."
    exit 1
  fi
else
  echo "Transaction not submitted. Signed transaction saved at: $tx_signed_path"
fi

echo ""
echo "=========================================="
echo "Test Case $test_case_number Summary"
echo "=========================================="
echo "Test case directory: $test_case_dir"
echo "Certificate: $tx_cert_path"
echo "Unsigned transaction: $tx_unsigned_path"
echo "Signed transaction: $tx_signed_path"
echo "Original PoolID: $pool_id"
echo "Poisoned PoolID: $poisoned_poolid"

