#!/bin/bash
set -euo pipefail

# Get the list of running containers
# Supports CARDANO_CONTAINER_NAME_OVERRIDE environment variable

# Check for container name override first
if [ -n "$CARDANO_CONTAINER_NAME_OVERRIDE" ]; then
  # Verify the container exists and is running
  if docker ps --format '{{.Names}}' | grep -q "^${CARDANO_CONTAINER_NAME_OVERRIDE}$"; then
    echo "$CARDANO_CONTAINER_NAME_OVERRIDE"
    exit 0
  else
    echo "Error: Container '$CARDANO_CONTAINER_NAME_OVERRIDE' is not running." >&2
    exit 1
  fi
fi

# Get the list of running containers
running_containers=$(docker ps --format '{{.Names}}')

# Convert the running containers to an array
IFS=$'\n' read -r -d '' -a running_containers <<< "$running_containers"

# Determine which container to use
if [ ${#running_containers[@]} -eq 1 ]; then
  # Single container: auto-select and set CARDANO_CONTAINER_NAME for consistency
  container_name="${running_containers[0]}"
  export CARDANO_CONTAINER_NAME="$container_name"
  echo "$container_name"
elif [ ${#running_containers[@]} -gt 1 ]; then
  # If running non-interactively (no TTY), use first container or fail
  if [ ! -t 0 ]; then
    container_name="${running_containers[0]}"
    echo "Warning: Multiple containers running but no TTY available. Using first container: $container_name" >&2
    export CARDANO_CONTAINER_NAME="$container_name"
    echo "$container_name"
  else
    select container_name in "${running_containers[@]}"; do
      if [ -n "$container_name" ]; then
        # Set environment variable so subsequent calls use this selection
        export CARDANO_CONTAINER_NAME="$container_name"
        echo "$container_name"
        break
      else
        echo "Invalid selection."
        exit 1
      fi
    done
  fi
else
  echo "No running containers found."
  exit 1
fi