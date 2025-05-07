#!/bin/bash

# Define directories
keys_dir="./keys"
txs_dir="./txs/drep"

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

# Registering you as a drep
echo "Registering you as a native script multisig DRep."

# Iterate through the template and add payment, stake and DRep keys to it
# cp ./scripts/drep/multi-sig-template.json $txs_dir/multisig-drep.json

# # Capture the keyHash values and ensure no newline characters
# newHash1=$(container_cli address key-hash --payment-verification-key-file "$keys_dir/payment.vkey" | tr -d '\n')
# newHash2=$(container_cli address key-hash --payment-verification-key-file "$keys_dir/payment.vkey" | tr -d '\n')
# newHash3=$(container_cli address key-hash --payment-verification-key-file "$keys_dir/payment.vkey" | tr -d '\n')

# # Use the captured values in jq
# updated_json=$(jq --arg newHash1 "$newHash1" \
#                   --arg newHash2 "$newHash2" \
#                   --arg newHash3 "$newHash3" \
#                   '.scripts[0].keyHash = $newHash1 | 
#                    .scripts[1].keyHash = $newHash2 | 
#                    .scripts[2].keyHash = $newHash3' "$txs_dir/multisig-drep.json")

# # Write the updated JSON to file
# echo "$updated_json" > "$txs_dir/multisig-drep.json"

container_cli hash script \
  --script-file $txs_dir/multisig-drep.json \
  --out-file $txs_dir/multisig-drep.id

container_cli conway governance drep registration-certificate \
 --drep-script-hash "$(cat $txs_dir/multisig-drep.id)" \
 --key-reg-deposit-amt "$(container_cli conway query gov-state | jq -r .currentPParams.dRepDeposit)" \
 --out-file $txs_dir/drep-multisig-register.cert

echo "Building transaction"

container_cli conway transaction build \
 --witness-override 2 \
 --tx-in $(container_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --change-address $(cat $keys_dir/payment.addr) \
 --certificate-file $txs_dir/drep-multisig-register.cert \
 --certificate-script-file $txs_dir/multisig-drep.json \
 --out-file $txs_dir/reg-drep-multisig-register.unsigned

container_cli conway transaction witness \
  --tx-body-file $txs_dir/reg-drep-multisig-register.unsigned \
  --signing-key-file $keys_dir/payment.skey \
  --out-file $txs_dir/reg-drep-multisig-register.witness

container_cli conway transaction assemble \
  --tx-body-file $txs_dir/reg-drep-multisig-register.unsigned \
  --witness-file $txs_dir/reg-drep-multisig-register.witness \
  --out-file $txs_dir/reg-drep-multisig-register.signed

echo "Submitting transaction"

container_cli conway transaction submit \
 --tx-file $txs_dir/reg-drep-multisig-register.signed
