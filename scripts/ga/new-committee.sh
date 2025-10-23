#!/bin/bash

# ~~~~~~~~~~~~ CHANGE THIS ~~~~~~~~~~~~
NEW_MEMBER_KEYHASH="xxx"
NEW_MEMBER_EXPIRATION="10000"

METADATA_URL="ipfs://bafkreia4ahcsnfegacpxypsgo2gpno5did6grm7ipqa6k2kivzsctlwlau"
METADATA_HASH="fd23ef0b70a2feaf8229aa1df79ed77f18b07881e35237a569730b2b261b99fc"
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Define directory paths
keys_dir="./keys"
txs_dir="./txs/ga"
tx_path_stub="$txs_dir/new-committee"
tx_cert_path="$tx_path_stub.action"
tx_unsigned_path="$tx_path_stub.unsigned"
tx_signed_path="$tx_path_stub.signed"

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

export THRESHOLD="2/3"

# Atlantic Council
export ADD_CC_1_SCRIPT_HASH="349e55f83e9af24813e6cb368df6a80d38951b2a334dfcdf26815558"
export ADD_CC_1_EXPIRATION="1083"

# Tingvard Council
export ADD_CC_2_SCRIPT_HASH="1980dbf1ad624b0cb5410359b5ab14d008561994a6c2b6c53fabec00"
export ADD_CC_2_EXPIRATION="1156"

# Eastern council
export ADD_CC_3_SCRIPT_HASH="84aebcfd3e00d0f87af918fc4b5e00135f407e379893df7e7d392c6a"
export ADD_CC_3_EXPIRATION="1156"

# Ktorz
export ADD_CC_4_KEY_HASH="dc0d6ef49590eb6880a50a00adde17596e6d76f7159572fa1ff85f2a"
export ADD_CC_4_EXPIRATION="1083"

# Ace Alliance
export ADD_CC_5_SCRIPT_HASH="9752e4306e5ae864441d21064f791174c8b626199b8e7a45f9e03b45"
export ADD_CC_5_EXPIRATION="1156"

# Cardano Japan Council
export ADD_CC_6_SCRIPT_HASH="9cc3f387623f45dae6a68b7096b0c2e403d8601a82dc40221ead41e2"
export ADD_CC_6_EXPIRATION="1083"

# Phil
export ADD_CC_7_KEY_HASH="13493790d9b03483a1e1e684ea4faf1ee48a58f402574e7f2246f4d4"
export ADD_CC_7_EXPIRATION="1083"

# Remove committee credentials
# IO
export REMOVE_CC_1_SCRIPT_HASH="df0e83bde65416dade5b1f97e7f115cc1ff999550ad968850783fe50"
# CF
export REMOVE_CC_2_SCRIPT_HASH="b6012034ba0a7e4afbbf2c7a1432f8824aee5299a48e38e41a952686"
# Emurgo
export REMOVE_CC_3_SCRIPT_HASH="ce8b37a72b178a37bbd3236daa7b2c158c9d3604e7aa667e6c6004b7"
# Intersect
export REMOVE_CC_4_SCRIPT_HASH="f0dc2c00d92a45521267be2d5de1c485f6f9d14466d7e16062897cf7"
# Japan Council
export REMOVE_CC_5_SCRIPT_HASH="e8165b3328027ee0d74b1f07298cb092fd99aa7697a1436f5997f625"

echo "Finding the previous Committee GA to reference"

GOV_STATE=$(container_cli conway query gov-state | jq -r '.nextRatifyState.nextEnactState.prevGovActionIds')

PREV_GA_TX_HASH=$(echo "$GOV_STATE" | jq -r '.Committee.txId')
PREV_GA_INDEX=$(echo "$GOV_STATE" | jq -r '.Committee.govActionIx')

echo "Previous Committee GA Tx Hash: $PREV_GA_TX_HASH#$PREV_GA_INDEX"

# Building, signing and submitting an new-committee change governance action
echo "Creating and submitting new-committee governance action."

container_cli conway governance action update-committee \
  --testnet \
  --governance-action-deposit $(container_cli conway query gov-state | jq -r '.currentPParams.govActionDeposit') \
  --deposit-return-stake-verification-key-file $keys_dir/stake.vkey \
  --remove-cc-cold-script-hash "6a0cd9563908692460413e08bef26eda0265ec23868fd1560d5cd42f" \
  --remove-cc-cold-script-hash "be4d67a5dd8de49543cc489aca920a377ea7a7e9855c8934d33e5765" \
  --remove-cc-cold-script-hash "886659e5bd42b14c8c909c2178837f0e612fec1c3469368acba4e331" \
  --add-cc-cold-script-hash "$ADD_CC_1_SCRIPT_HASH" \
  --epoch "$ADD_CC_1_EXPIRATION" \
  --add-cc-cold-script-hash "$ADD_CC_2_SCRIPT_HASH" \
  --epoch "$ADD_CC_2_EXPIRATION" \
  --add-cc-cold-script-hash "$ADD_CC_3_SCRIPT_HASH" \
  --epoch "$ADD_CC_3_EXPIRATION" \
  --add-cc-cold-verification-key-hash "$ADD_CC_4_KEY_HASH" \
  --epoch "$ADD_CC_4_EXPIRATION" \
  --add-cc-cold-script-hash "$ADD_CC_5_SCRIPT_HASH" \
  --epoch "$ADD_CC_5_EXPIRATION" \
  --add-cc-cold-script-hash "$ADD_CC_6_SCRIPT_HASH" \
  --epoch "$ADD_CC_6_EXPIRATION" \
  --add-cc-cold-verification-key-hash "$ADD_CC_7_KEY_HASH" \
  --epoch "$ADD_CC_7_EXPIRATION" \
  --threshold "$THRESHOLD" \
  --anchor-url "$METADATA_URL" \
  --anchor-data-hash "$METADATA_HASH" \
  --check-anchor-data \
  --prev-governance-action-tx-id "6214314b6d6a30118d259c9597c0e0120b76aa521e322044c4290fcaac86e27a" \
  --prev-governance-action-index "0" \
  --out-file "$tx_cert_path"

echo "Building transaction"

container_cli conway transaction build \
 --tx-in "$(container_cli conway query utxo --address "$(cat $keys_dir/payment.addr)" --out-file /dev/stdout | jq -r 'keys[0]')" \
 --proposal-file "$tx_cert_path" \
 --change-address "$(cat $keys_dir/payment.addr)" \
 --out-file "$tx_unsigned_path" \

echo "Signing transaction"

container_cli conway transaction sign \
 --tx-body-file "$tx_unsigned_path" \
 --signing-key-file $keys_dir/payment.skey \
 --out-file "$tx_signed_path" \

# Submit the transaction
echo "Submitting transaction"

container_cli conway transaction submit --tx-file $tx_signed_path
