#!/bin/sh
# Amaru entrypoint wrapper script
# Based on Amaru CLI documentation: amaru run --peer-address <NETWORK_ADDRESS> --network <NETWORK>

set -e

# Use environment variables set in the container
NETWORK="${AMARU_NETWORK:-preprod}"
PEER_ADDRESS="${AMARU_PEER_ADDRESS:-127.0.0.1:3001}"

# Amaru run command syntax: amaru run --peer-address <NETWORK_ADDRESS> --network <NETWORK>
# Note: --port is not a valid argument according to the CLI
exec amaru run --peer-address "$PEER_ADDRESS" --network "$NETWORK" "$@"

