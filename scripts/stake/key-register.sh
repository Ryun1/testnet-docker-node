#!/bin/bash

# Define directory paths
keys_dir="./keys"
txs_dir="./txs/stake"
tx_path_stub="$txs_dir/stake-register"
tx_cert_path="$tx_path_stub.cert"
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

# Registering your stake key
echo "Registering your stake key."

container_cli conway stake-address registration-certificate \
 --stake-verification-key-file $keys_dir/stake.vkey \
 --key-reg-deposit-amt "$(container_cli conway query gov-state | jq -r .currentPParams.stakeAddressDeposit)" \
 --out-file "$tx_cert_path"

echo "Building transaction"

container_cli conway transaction build \
 --witness-override 2 \
 --tx-in $(container_cli conway query utxo --address $(cat $keys_dir/payment.addr) --out-file  /dev/stdout | jq -r 'keys[1]') \
 --change-address $(cat $keys_dir/payment.addr) \
 --certificate-file "$tx_cert_path" \
 --out-file "$tx_unsigned_path"

echo "Signing transaction"

container_cli conway transaction sign \
 --tx-body-file "$tx_unsigned_path" \
 --signing-key-file $keys_dir/payment.skey \
 --signing-key-file $keys_dir/stake.skey \
 --out-file "$tx_signed_path"

# Submit the transaction
echo "Submitting transaction"

if container_cli conway transaction submit --tx-file $tx_signed_path; then
  # Get the transaction ID
  transaction_id=$(container_cli conway transaction txid --tx-file $tx_signed_path)
  echo "Follow the transaction at: $transaction_id"
else
  echo "Transaction submission failed."
  exit 1
fi
