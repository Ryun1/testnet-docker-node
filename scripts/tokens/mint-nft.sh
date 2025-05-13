#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~

token_amount=1 # set to 1 for NFT, as each is unique

# The name of the NFT collection
token_collection_name="intersect-founding-membership"
# The name of the NFT collection
token_name_hex=$(echo -n $token_collection_name | xxd -b -s -c 80 | tr -d '\n')

# Some metadata fields for the NFT
# limited to 64 chars
token_description="you're a member of the intersect community!!"
image="bafybeidyyrslra2dy22i3jjqz6wvvsqzh5ibrah5ksh444ztvzwpqt4z4q"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directory paths
keys_dir="./keys"
txs_dir="./txs/tokens"

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

echo " "
echo "Creating policy script"
echo " "
echo "Setting your policy script only allow your payment key to mint tokens"
echo "Other logic can be added to the script, but this is a simple example"
echo " "

> "$txs_dir/nft-policy.script"

# Get payment key hash
payment_key_hash="$(container_cli address key-hash --payment-verification-key-file "$keys_dir/payment.vkey" | cut -c1-56)"

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

echo "Have a look at the policy script"
echo "This limits the minting of tokens"
echo " "
echo "$(cat $txs_dir/nft-policy.script)"

# Hash the script to get the policy ID
echo "Creating policy ID from script"

container_cli conway transaction policyid \
   --script-file $txs_dir/nft-policy.script | cut -c1-56 > $txs_dir/nft-policy.id

# policy_id="$(container_cli conway transaction policyid --script-file $txs_dir/nft-policy.script)"

echo "Policy ID: $policy_id"

# Make some metadata for the NFT
echo "Creating metadata for minting the first NFT of this policy"

# > "$txs_dir/nft-metadata.json"

# echo "{" >> $txs_dir/nft-metadata.json
# echo "  \"721\": {" >> $txs_dir/nft-metadata.json
# echo "    \"$policy_id\": {" >> $txs_dir/nft-metadata.json
# echo "      \"$token_collection_name\": {" >> $txs_dir/nft-metadata.json
# echo "        \"description\": \"$token_description\"," >> $txs_dir/nft-metadata.json
# echo "        \"name\": \"$token_collection_name\"," >> $txs_dir/nft-metadata.json
# echo "        \"id\": \"1\"," >> $txs_dir/nft-metadata.json
# echo "        \"image\": \"ipfs://$(echo $ipfs_CID)\"" >> $txs_dir/nft-metadata.json
# echo "      }" >> $txs_dir/nft-metadata.json
# echo "    }" >> $txs_dir/nft-metadata.json
# echo "  }" >> $txs_dir/nft-metadata.json
# echo "}" >> $txs_dir/nft-metadata.json

# echo " "
# echo "Have a look at the metadata we will attach to the first NFT"
# echo " "
# echo "$(cat $txs_dir/nft-metadata.json)"

# echo "Building the minting transaction for the first NFT"

# output=1400000

# container_cli conway transaction build \
#  --witness-override 2 \
#  --tx-in $(container_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
#  --tx-out $(cat $keys_dir/payment.addr)+$output+"$token_amount $policy_id.$token_collection_name_hex" \
#  --change-address $(cat $keys_dir/payment.addr) \
#  --mint="$token_amount $policy_id.$token_collection_name_hex" \
#  --minting-script-file $txs_dir/nft-policy.script \
#  --metadata-json-file $txs_dir/nft-metadata.json \
#  --out-file $txs_dir/mint-nft.unsigned

# echo "Signing transaction"

# container_cli conway transaction sign \
#  --tx-body-file $txs_dir/mint-nft.unsigned \
#  --signing-key-file $keys_dir/payment.skey \
#  --out-file $txs_dir/mint-nft.signed

# echo "Submitting transaction"

# container_cli conway transaction submit \
#  --tx-file $txs_dir/mint-nft.signed