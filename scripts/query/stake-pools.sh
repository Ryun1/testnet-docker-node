#!/bin/bash
set -euo pipefail

# Get the script's directory
script_dir=$(dirname "$0")


# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

# Query the stake pools
cardano_cli conway query stake-pools