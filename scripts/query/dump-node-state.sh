#!/bin/bash
set -euo pipefail

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/.." && pwd)

# Define directory paths relative to project root
dumps_dir="$project_root/dumps"

# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

# Get the network name
if [ -n "$CARDANO_NETWORK" ]; then
  network="$CARDANO_NETWORK"
elif [ "$NODE_MODE" = "docker" ]; then
  # For Docker mode, extract from container name
  container_name="$("$script_dir/../helper/get-container.sh")"
  network=$(echo $container_name | cut -d'-' -f2)
else
  echo "Error: Could not determine network name. Please set CARDANO_NETWORK environment variable." >&2
  exit 1
fi


# Dumping out CC state
echo "Dumping constitutional committee state."

cardano_cli conway query committee-state > ./dumps/$network/committee.json

# Dumping out constitution state
echo "Dumping constitution state."


cardano_cli conway query constitution > ./dumps/$network/constitution.json

# Query DReps from ledger state
echo "Dumping DReps from ledger state."


cardano_cli conway query drep-state \
  --all-dreps > ./dumps/$network/dreps-info.json

cardano_cli conway query drep-stake-distribution \
  --all-dreps > ./dumps/$network/dreps-power.json

# Dumping governance ledger state
echo "Dumping whole governance state from ledger state."


cardano_cli conway query gov-state > ./dumps/$network/gov-state.json

# Dumping proposals stored in ledger state
echo "Dumping governance actions from ledger state."


cardano_cli conway query gov-state | jq -r '.proposals' > ./dumps/$network/governance-actions.json

# Dumping out parameters state
echo "Dumping protocol parameters state."


cardano_cli conway query protocol-parameters > ./dumps/$network/params.json

# Dumping out SPO state
echo "Dumping SPO stake distribution state."


cardano_cli conway query spo-stake-distribution \
 --all-spos > ./dumps/$network/spo-stake.json

# Dumping out SPO state
echo "Dumping treasury state."


cardano_cli conway query treasury > ./dumps/$network/treasury.json
