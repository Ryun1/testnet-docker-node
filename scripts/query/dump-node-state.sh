#!/bin/bash

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

# Get the network name

# Split the container name and extract the second part
network=$(echo $container_name | cut -d'-' -f2)

# Dumping out CC state
echo "Dumping constitutional committee state."

container_cli conway query committee-state > ./dumps/$network/committee.json

# Dumping out constitution state
echo "Dumping constitution state."

container_cli conway query constitution > ./dumps/$network/constitution.json

# Query DReps from ledger state
echo "Dumping DReps from ledger state."

container_cli conway query drep-state \
  --all-dreps > ./dumps/$network/dreps-info.json

container_cli conway query drep-stake-distribution \
  --all-dreps > ./dumps/$network/dreps-power.json

# Dumping governance ledger state
echo "Dumping whole governance state from ledger state."

container_cli conway query gov-state > ./dumps/$network/gov-state.json

# Dumping proposals stored in ledger state
echo "Dumping governance actions from ledger state."

container_cli conway query gov-state | jq -r '.proposals' > ./dumps/$network/governance-actions.json

# Dumping out parameters state
echo "Dumping protocol parameters state."

container_cli conway query protocol-parameters > ./dumps/$network/params.json

# Dumping out SPO state
echo "Dumping SPO stake distribution state."

container_cli conway query spo-stake-distribution \
 --all-spos > ./dumps/$network/spo-stake.json

# Dumping out SPO state
echo "Dumping treasury state."

container_cli conway query treasury > ./dumps/$network/treasury.json