# Define build-time variables
ARG CARDANO_NODE_VERSION=10.5.3 # Default fallback if not provided
ARG CARDANO_NODE_NETWORK_ID

FROM ghcr.io/intersectmbo/cardano-node:${CARDANO_NODE_VERSION}

# Set environment variables
ENV CARDANO_NODE_SOCKET_PATH=/ipc/node.socket
ENV CARDANO_NODE_NETWORK_ID=${CARDANO_NODE_NETWORK_ID}
ENV IPFS_GATEWAY_URI="https://ipfs.io/"

ENTRYPOINT ["/usr/local/bin/cardano-node", "run", "+RTS", "-N", "-A16m", "-qg", "-qb", "-RTS", "--topology", "/config/topology.json", "--database-path", "/data/db", "--socket-path", "/ipc/node.socket", "--host-addr", "0.0.0.0", "--port", "3001", "--config", "/config/config.json" ]