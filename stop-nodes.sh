#!/bin/bash
set -euo pipefail

# Stop all node containers matching the pattern (node|amaru)-*-*-container
# This handles versioned containers (e.g., node-preprod-10.5.3-container, amaru-preprod-latest-container)
echo "Stopping all node containers..."

# Get all running containers and filter for node-*-*-container and amaru-*-*-container patterns
containers=$(docker ps --format "{{.Names}}" | grep -E "^(node|amaru)-[^-]+-[^-]+-container$" || true)

if [ -z "$containers" ]; then
  echo "No node containers found running."
  exit 0
fi

# Stop each container
for container in $containers; do
  echo "Stopping container: $container"
  docker stop "$container" 2>/dev/null || true
  docker rm "$container" 2>/dev/null || true
done

echo "All node containers stopped."