#!/bin/bash

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
scripts_dir="$project_root/scripts"

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

echo "Creating three keys to control a multi-sig script."

# Create directory for keys
mkdir -p "$keys_dir/multi-sig"

# Key 1
container_cli address key-gen \
 --verification-key-file "$keys_dir/multi-sig/1.vkey" \
 --signing-key-file "$keys_dir/multi-sig/1.skey"

container_cli address key-hash \
  --payment-verification-key-file "$keys_dir/multi-sig/1.vkey" > "$keys_dir/multi-sig/1.keyhash"

# Key 2
container_cli address key-gen \
 --verification-key-file "$keys_dir/multi-sig/2.vkey" \
 --signing-key-file "$keys_dir/multi-sig/2.skey"

container_cli address key-hash \
  --payment-verification-key-file "$keys_dir/multi-sig/2.vkey" > "$keys_dir/multi-sig/2.keyhash"

# Key 3
container_cli address key-gen \
 --verification-key-file "$keys_dir/multi-sig/3.vkey" \
 --signing-key-file "$keys_dir/multi-sig/3.skey"

container_cli address key-hash \
  --payment-verification-key-file "$keys_dir/multi-sig/3.vkey" > "$keys_dir/multi-sig/3.keyhash"

echo "Copying the script template."

cp "$scripts_dir/multi-sig/multi-sig-template.json" "$keys_dir/multi-sig/script.json"

echo "Adding keys to script."

# Remove \r from the key hashes when reading them
jq --arg kh1 "$(tr -d '\r' < "$keys_dir/multi-sig/1.keyhash")" \
   --arg kh2 "$(tr -d '\r' < "$keys_dir/multi-sig/2.keyhash")" \
   --arg kh3 "$(tr -d '\r' < "$keys_dir/multi-sig/3.keyhash")" \
'.scripts[0].keyHash = $kh1 | .scripts[1].keyHash = $kh2 | .scripts[2].keyHash = $kh3' \
"$keys_dir/multi-sig/script.json" > temp.json && mv temp.json "$keys_dir/multi-sig/script.json"

echo "Creating script address."

container_cli address build \
  --payment-script-file "$keys_dir/multi-sig/script.json" \
  --out-file "$keys_dir/multi-sig/script.addr"

echo "Done!"