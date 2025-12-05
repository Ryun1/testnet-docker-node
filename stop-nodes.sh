#!/bin/bash
set -euo pipefail

# Stop all cardano node containers matching the pattern node-*-*-container
# This handles versioned containers (e.g., node-preprod-10.5.3-container)
echo "Stopping all Cardano node containers..."

# Get all running containers and filter for node-*-*-container pattern
containers=$(docker ps --format "{{.Names}}" | grep -E "^node-[^-]+-[^-]+-container$" || true)

if [ -z "$containers" ]; then
  echo "No Cardano node containers found running."
  exit 0
fi

# Stop each container
for container in $containers; do
  echo "Stopping container: $container"
  docker stop "$container" 2>/dev/null || true
  docker rm "$container" 2>/dev/null || true
done

echo "All Cardano node containers stopped."