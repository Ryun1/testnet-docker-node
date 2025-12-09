#!/bin/bash
# set -euo pipefail

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
  echo "${running_containers[0]}"
elif [ ${#running_containers[@]} -gt 1 ]; then
  # If running non-interactively (no TTY), use first container or fail
  if [ ! -t 0 ]; then
    echo "Warning: Multiple containers running but no TTY available. Using first container: ${running_containers[0]}" >&2
    echo "${running_containers[0]}"
  else
    select container_name in "${running_containers[@]}"; do
      if [ -n "$container_name" ]; then
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