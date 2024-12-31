#!/bin/sh

# Define directories
keys_dir="./keys"

# Function to execute cardano-cli commands inside the container
container_cli() {
  docker exec -ti sancho-node cardano-cli "$@"
}

# Check if you have a address created
if [ ! -f "./$keys_dir/payment.addr" ]; then
  echo "Please generate some keys and addresses before querying funds."
  echo "Exiting."
  exit 0
fi

echo "Querying UTXOs for your address: $(cat ./$keys_dir/payment.addr)"

# Query the UTxOs controlled by the payment address
container_cli conway query utxo \
  --address "$(cat ./$keys_dir/payment.addr)" \
  --testnet-magic 4 \
  --out-file  /dev/stdout