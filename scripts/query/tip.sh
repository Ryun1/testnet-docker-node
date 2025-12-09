#!/bin/bash
set -euo pipefail

# Get the script's directory
script_dir=$(dirname "$0")

# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

# Query the tip of the blockchain as observed by the node
cardano_cli conway query tip