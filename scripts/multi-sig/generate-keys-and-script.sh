#!/bin/bash
set -euo pipefail

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
keys_dir="$project_root/keys"
scripts_dir="$project_root/scripts"

# Check required template file exists
if [ ! -f "$scripts_dir/multi-sig/multi-sig-template.json" ]; then
  echo "Error: Multi-sig template file not found: $scripts_dir/multi-sig/multi-sig-template.json"
  exit 1
fi


# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

echo "Creating three keys to control a multi-sig script."

# Create directory for keys
mkdir -p "$keys_dir/multi-sig"

# Key 1

cardano_cli address key-gen \
 --verification-key-file keys/multi-sig/1.vkey \
 --signing-key-file keys/multi-sig/1.skey

cardano_cli address key-hash \
  --payment-verification-key-file keys/multi-sig/1.vkey > keys/multi-sig/1.keyhash

# Key 2
cardano_cli address key-gen \
 --verification-key-file keys/multi-sig/2.vkey \
 --signing-key-file keys/multi-sig/2.skey

cardano_cli address key-hash \
  --payment-verification-key-file keys/multi-sig/2.vkey > keys/multi-sig/2.keyhash

# Key 3
cardano_cli address key-gen \
 --verification-key-file keys/multi-sig/3.vkey \
 --signing-key-file keys/multi-sig/3.skey

cardano_cli address key-hash \
  --payment-verification-key-file keys/multi-sig/3.vkey > keys/multi-sig/3.keyhash

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

cardano_cli address build \
  --payment-script-file "$keys_dir/multi-sig/script.json" \
  --out-file "$keys_dir/multi-sig/script.addr"

echo "Done!"