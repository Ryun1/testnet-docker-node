#!/bin/bash

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
txs_dir="$project_root/txs/multi-sig"

# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

# Helper function to get UTXO with validation
get_utxo() {
  local address=$1
  local utxo_output
  utxo_output=$(cardano_cli conway query utxo --address "$address" --out-file /dev/stdout)
  local utxo
  utxo=$(echo "$utxo_output" | jq -r 'keys[0]')
  if [ -z "$utxo" ] || [ "$utxo" = "null" ]; then
    echo "Error: No UTXO found at address: $address" >&2
    exit 1
  fi
  echo "$utxo"
}


# Registering you as a drep
echo "Registering you as a native script multisig DRep."

# Iterate through the template and add payment, stake and DRep keys to it
# cp ./scripts/drep/multi-sig-template.json $txs_dir/multisig-drep.json

# # Capture the keyHash values and ensure no newline characters
# newHash1=$(cardano_cli address key-hash --payment-verification-key-file "$keys_dir/payment.vkey" | tr -d '\n')
# newHash2=$(cardano_cli address key-hash --payment-verification-key-file "$keys_dir/payment.vkey" | tr -d '\n')
# newHash3=$(cardano_cli address key-hash --payment-verification-key-file "$keys_dir/payment.vkey" | tr -d '\n')

# # Use the captured values in jq
# updated_json=$(jq --arg newHash1 "$newHash1" \
#                   --arg newHash2 "$newHash2" \
#                   --arg newHash3 "$newHash3" \
#                   '.scripts[0].keyHash = $newHash1 | 
#                    .scripts[1].keyHash = $newHash2 | 
#                    .scripts[2].keyHash = $newHash3' "$txs_dir/multisig-drep.json")

# # Write the updated JSON to file
# echo "$updated_json" > "$txs_dir/multisig-drep.json"

cardano_cli hash script \
  --script-file $txs_dir/drep-one-sig.json \
  --out-file $txs_dir/drep-one-sig.id

cardano_cli conway governance drep registration-certificate \
 --drep-script-hash "$(cat $txs_dir/drep-one-sig.id)" \
 --key-reg-deposit-amt "$(cardano_cli conway query gov-state | jq -r .currentPParams.dRepDeposit)" \
 --out-file $txs_dir/drep-multisig-register.cert

echo "Building transaction"

cardano_cli conway transaction build \
 --witness-override 2 \
 --tx-in $(cardano_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[0]') \
 --change-address $(cat $keys_dir/payment.addr) \
 --certificate-file $txs_dir/drep-multisig-register.cert \
 --certificate-script-file $txs_dir/drep-one-sig.json \
 --out-file $txs_dir/reg-drep-multisig-register.unsigned

cardano_cli conway transaction witness \
  --tx-body-file $txs_dir/reg-drep-multisig-register.unsigned \
  --signing-key-file $keys_dir/payment.skey \
  --out-file $txs_dir/reg-drep-multisig-register.witness

cardano_cli conway transaction witness \
  --tx-body-file $txs_dir/reg-drep-multisig-register.unsigned \
  --signing-key-file $keys_dir/multi-sig/1.skey \
  --out-file $txs_dir/reg-drep-multisig-register-1.witness

cardano_cli conway transaction assemble \
  --tx-body-file $txs_dir/reg-drep-multisig-register.unsigned \
  --witness-file $txs_dir/reg-drep-multisig-register.witness \
  --witness-file $txs_dir/reg-drep-multisig-register-1.witness \
  --out-file $txs_dir/reg-drep-multisig-register.signed

echo "Submitting transaction"

cardano_cli conway transaction submit \
 --tx-file $txs_dir/reg-drep-multisig-register.signed
