# Define build-time variables for FROM statement
ARG CARDANO_NODE_VERSION=10.5.3

FROM ghcr.io/intersectmbo/cardano-node:${CARDANO_NODE_VERSION}

# Redefine build arguments for use in this stage
ARG CARDANO_NODE_NETWORK_ID
ARG CARDANO_NODE_PORT=3001

# Set environment variables
ENV CARDANO_NODE_SOCKET_PATH=/ipc/node.socket
ENV CARDANO_NODE_NETWORK_ID=${CARDANO_NODE_NETWORK_ID}
ENV CARDANO_NODE_PORT=${CARDANO_NODE_PORT}
ENV IPFS_GATEWAY_URI="https://ipfs.io/"

# Use shell form to allow variable expansion
ENTRYPOINT /usr/local/bin/cardano-node run +RTS -N -A16m -qg -qb -RTS --topology /config/topology.json --database-path /data/db --socket-path /ipc/node.socket --host-addr 0.0.0.0 --port ${CARDANO_NODE_PORT} --config /config/config.json