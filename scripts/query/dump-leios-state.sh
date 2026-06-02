#!/bin/bash
set -euo pipefail

# Get the script's directory and project root
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Define directory paths relative to project root
dumps_dir="$project_root/dumps"

# Source the cardano-cli wrapper
source "$script_dir/../helper/cardano-cli-wrapper.sh"

# Get the network name
if [ -n "${CARDANO_NETWORK:-}" ]; then
  network="$CARDANO_NETWORK"
elif [ "$NODE_MODE" = "docker" ]; then
  # For Docker mode, extract from container name
  container_name="$("$script_dir/../helper/get-container.sh")"
  network=$(echo $container_name | cut -d'-' -f2)
else
  echo "Error: Could not determine network name. Please set CARDANO_NETWORK environment variable." >&2
  exit 1
fi

# Ensure the output directory exists
out_dir="./dumps/$network"
mkdir -p "$out_dir"

# Helper: run a query and write to file, warning (not aborting) on failure.
# Usage: dump <output-file> <query subcommand...>
dump() {
  local out_file="$1"; shift
  echo "Dumping ${out_file}..."
  if ! cardano_cli query "$@" > "$out_dir/$out_file" 2>"$out_dir/$out_file.err"; then
    echo "  Warning: 'query $*' failed; see $out_dir/$out_file.err" >&2
    return 0
  fi
  rm -f "$out_dir/$out_file.err"
}

echo "Dumping Leios/Dijkstra node state for network: $network"

# --- Queries that need no extra arguments ---------------------------------
dump tip.json              tip
dump params.json           protocol-parameters
dump stake-pools.json      stake-pools
dump stake-distribution.json stake-distribution
dump era-history.json      era-history
dump ledger-state.json     ledger-state
dump protocol-state.json   protocol-state

# --- Queries that need an "all"/scope selector ----------------------------
dump pool-state.json           pool-state --all-stake-pools
dump stake-snapshot.json       stake-snapshot --all-stake-pools
dump tx-mempool.json           tx-mempool info
dump ledger-peer-snapshot.json ledger-peer-snapshot --all-ledger-peers
dump utxo-whole.json           utxo --whole-utxo

# --- Queries that depend on local keys (only if present) ------------------
keys_dir="$project_root/keys"

if [ -f "$keys_dir/stake.addr" ]; then
  dump stake-address-info.json stake-address-info --address "$(cat "$keys_dir/stake.addr")"
else
  echo "Skipping stake-address-info: $keys_dir/stake.addr not found." >&2
fi

# kes-period-info needs the node's operational certificate. Set OP_CERT_FILE
# to its path to include it, e.g. OP_CERT_FILE=keys/node.cert ./dump-leios-state.sh
if [ -n "${OP_CERT_FILE:-}" ] && [ -f "$OP_CERT_FILE" ]; then
  dump kes-period-info.json kes-period-info --op-cert-file "$OP_CERT_FILE"
else
  echo "Skipping kes-period-info: set OP_CERT_FILE to the node operational certificate to include it." >&2
fi

# --- Queries that require operator-specific input (not auto-dumped) --------
# leadership-schedule needs --genesis, a pool key/id, and --vrf-signing-key-file:
#   cardano_cli query leadership-schedule --genesis <shelley-genesis.json> \
#     --stake-pool-id <POOL_ID> --vrf-signing-key-file <vrf.skey> --current
# slot-number needs a UTC timestamp:
#   cardano_cli query slot-number 2025-01-01T00:00:00Z

echo "Done. Output written to $out_dir/"
