FROM ghcr.io/blinklabs-io/cardano-node:latest

# Set environment variables for BlinkLabs container
ENV CARDANO_CONFIG_BASE=/opt/cardano/config
ENV CARDANO_DATABASE_PATH=/data/db
ENV CARDANO_SOCKET_PATH=/ipc/node.socket
ENV CARDANO_BIND_ADDR=0.0.0.0
ENV CARDANO_PORT=3001
ENV IPFS_GATEWAY_URI="https://ipfs.io/"

# Use the 'run' command for full configurability
ENTRYPOINT ["/usr/local/bin/entrypoint", "run"]