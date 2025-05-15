#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
amount=5000000

script_location="https://raw.githubusercontent.com/Ryun1/idk-aiken/refs/heads/main/script.json"

token_amount=1 # set to 1 for NFT, as each is unique

# The name of the NFT collection
token_collection_name="epic-nft-collection"
# The name of the NFT collection
token_collection_name_hex=$(echo -n $token_collection_name | xxd -b -s -c 80 | tr -d '\n')
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directories
keys_dir="./keys"
txs_dir="./txs/smart-contract"

# Get the script's directory
script_dir=$(dirname "$0")

# Get the container name from the get-container script
container_name="$("$script_dir/../helper/get-container.sh")"

if [ -z "$container_name" ]; then
  echo "Failed to determine a running container."
  exit 1
fi

echo "Using running container: $container_name"

# Function to execute cardano-cli commands inside the container
container_cli() {
  docker exec -ti $container_name cardano-cli "$@"
}

# Send five ada to script address
echo "Sending $amount lovelace to script"

# Download the script
echo "Downloading script from $script_location"
curl -s -o $txs_dir/script.json $script_location

# Check if the script file exists
if [ ! -f "$txs_dir/script.json" ]; then
  echo "Script file not found: $txs_dir/script.json"
  exit 1
fi

# Get the script address
container_cli conway address build \
  --payment-script-file $txs_dir/script.json \
  --out-file $txs_dir/script.addr

echo "Script address: $(cat $txs_dir/script.addr)"

# Get payment key hash
payment_key_hash="$(container_cli address key-hash --payment-verification-key-file "$keys_dir/payment.vkey" | cut -c1-56)"

echo "building datum.json with payment key hash: $payment_key_hash"
echo "{\"constructor\": 0, \"fields\": [{ \"bytes\": \"$payment_key_hash\" }]}" > $txs_dir/datum.json

echo " "
echo "Creating policy script"
echo "Setting your policy script only allow your payment key to mint tokens"
echo "Other logic can be added to the script, but this is a simple example"
echo " "

> "$txs_dir/nft-policy.script"

echo "{" >> $txs_dir/nft-policy.script
echo "  \"type\": \"all\"," >> $txs_dir/nft-policy.script
echo "  \"scripts\":" >> $txs_dir/nft-policy.script
echo "  [" >> $txs_dir/nft-policy.script
echo "   {" >> $txs_dir/nft-policy.script
echo "     \"type\": \"sig\"," >> $txs_dir/nft-policy.script
echo "     \"keyHash\": \"$payment_key_hash\"" >> $txs_dir/nft-policy.script
echo "   }" >> $txs_dir/nft-policy.script
echo "  ]" >> $txs_dir/nft-policy.script
echo "}" >> $txs_dir/nft-policy.script

# Remove any trailing newline from the JSON file
truncate -s $(($(wc -c < $txs_dir/nft-policy.script) - 1)) $txs_dir/nft-policy.script

# Hash the script to get the policy ID
echo "Creating policy ID from script"

container_cli conway transaction policyid \
   --script-file $txs_dir/nft-policy.script | cut -c1-56 > $txs_dir/nft-policy.id

truncate -s $(($(wc -c < $txs_dir/nft-policy.id) - 1)) $txs_dir/nft-policy.id

policy_id="$(cat $txs_dir/nft-policy.id)"

echo "Policy ID: $policy_id"

# build the transaction
echo "Building transaction"

container_cli conway transaction build \
 --tx-in $(container_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[2]') \
 --tx-in $(container_cli conway query utxo --address $(cat $txs_dir/script.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --tx-in-inline-datum-present \
 --tx-in-redeemer-value {} \
 --tx-in-script-file $txs_dir/script.json \
 --tx-out $(cat $keys_dir/payment.addr)+$amount+"$token_amount $policy_id.$token_collection_name_hex" \
 --mint="$token_amount $policy_id.$token_collection_name_hex" \
 --minting-script-file $txs_dir/nft-policy.script \
 --tx-in-collateral $(container_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[4]') \
 --change-address $(cat $keys_dir/payment.addr) \
 --required-signer-hash $payment_key_hash \
 --out-file $txs_dir/mint-with-contract.unsigned

# Sing the transaction
echo "Signing transaction"

container_cli conway transaction sign \
 --tx-body-file $txs_dir/mint-with-contract.unsigned \
 --signing-key-file $keys_dir/payment.skey \
 --out-file $txs_dir/mint-with-contract.signed

# Submit Transaction
echo "Submitting transaction"

container_cli conway transaction submit \
 --tx-file $txs_dir/mint-with-contract.signed

