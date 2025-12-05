#!/bin/bash

# Unified wrapper for cardano-cli that supports both Docker and external node modes
# This script should be sourced by other scripts

# Get the script's directory (works when sourced)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
source "$script_dir/load-config.sh"

# Check cardano-cli version and display node info (only once, when wrapper is sourced)
check_cardano_cli_version() {
  if [ "$NODE_MODE" = "external" ]; then
    if ! command -v cardano-cli &> /dev/null; then
      echo "Warning: cardano-cli not found in PATH. External node mode requires cardano-cli to be installed locally." >&2
      return 1
    fi
    
    local cli_version=$(cardano-cli version 2>/dev/null | head -n 1 || echo "unknown")
    # Clean up version string (remove "cardano-cli" prefix if present)
    cli_version=$(echo "$cli_version" | sed 's/^cardano-cli //')
    
    if [ -n "$CARDANO_NETWORK" ]; then
      echo "Info: External node | $CARDANO_NETWORK | cardano-cli $cli_version" >&2
    else
      echo "Info: External node | network ID: $CARDANO_NODE_NETWORK_ID | cardano-cli $cli_version" >&2
    fi
  elif [ "$NODE_MODE" = "docker" ]; then
    # Get container name (only if explicitly set to avoid interactive selection)
    local container_name=""
    if [ -n "$CARDANO_CONTAINER_NAME" ]; then
      container_name="$CARDANO_CONTAINER_NAME"
    elif [ -n "$CARDANO_CONTAINER_NAME_OVERRIDE" ]; then
      container_name="$CARDANO_CONTAINER_NAME_OVERRIDE"
    else
      # Only try to get container name if there's exactly one running container (non-interactive)
      local running_count=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E '^node-' | wc -l | tr -d ' ')
      if [ "$running_count" -eq 1 ]; then
        container_name=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E '^node-' | head -n 1)
      fi
    fi
    
    if [ -n "$container_name" ]; then
      # Extract network and version from container name (pattern: node-{network}-{version}-container)
      local network=""
      local node_version=""
      if [[ "$container_name" =~ ^node-([^-]+)-([^-]+)-container$ ]]; then
        network="${BASH_REMATCH[1]}"
        node_version="${BASH_REMATCH[2]}"
      fi
      
      # Get cardano-cli version from container
      local cli_version=$(docker exec "$container_name" cardano-cli version 2>/dev/null | head -n 1 || echo "unknown")
      # Clean up version string (remove "cardano-cli" prefix if present)
      cli_version=$(echo "$cli_version" | sed 's/^cardano-cli //')
      
      if [ -n "$network" ] && [ -n "$node_version" ]; then
        echo "Info: node v$node_version | $network | cardano-cli $cli_version" >&2
      else
        echo "Info: Docker container: $container_name | cardano-cli $cli_version" >&2
      fi
    fi
  fi
}

# Get container name for Docker mode
get_container_name() {
  if [ "$NODE_MODE" = "docker" ]; then
    # Check for direct container name specification
    if [ -n "$CARDANO_CONTAINER_NAME" ]; then
      # Verify the container exists and is running
      if docker ps --format '{{.Names}}' | grep -q "^${CARDANO_CONTAINER_NAME}$"; then
        echo "$CARDANO_CONTAINER_NAME"
        return 0
      else
        echo "Error: Container '$CARDANO_CONTAINER_NAME' is not running." >&2
        exit 1
      fi
    fi
    # Use get-container.sh (which handles CARDANO_CONTAINER_NAME_OVERRIDE)
    "$script_dir/get-container.sh"
  fi
}

# Unified cardano-cli function
cardano_cli() {
  local network_flag_args=()
  local is_mainnet=false
  local needs_network_flag=false
  
  # Check if command needs network flags
  # Query commands that connect to node socket don't need network flags
  # Commands that need network flags: address, transaction building, some key operations
  local first_arg="${1:-}"
  local second_arg="${2:-}"
  
  # Commands that typically need network flags
  case "$first_arg" in
    address|transaction|key)
      needs_network_flag=true
      ;;
    query)
      # Query commands don't need network flags when connecting via socket
      needs_network_flag=false
      ;;
    *)
      # For other commands, check if they're query-like (connect to node)
      # If second arg is "query", it's a query command
      if [ "$second_arg" = "query" ]; then
        needs_network_flag=false
      else
        # Default to needing network flag for safety (address, transaction, etc.)
        needs_network_flag=true
      fi
      ;;
  esac
  
  # Determine network flag if needed
  if [ "$needs_network_flag" = true ]; then
    if [ -n "$CARDANO_NODE_NETWORK_ID" ]; then
      if [ "$CARDANO_NODE_NETWORK_ID" = "764824073" ]; then
        is_mainnet=true
        network_flag_args=("--mainnet")
      else
        network_flag_args=("--testnet-magic" "$CARDANO_NODE_NETWORK_ID")
      fi
    elif [ -n "$CARDANO_NETWORK" ]; then
      case "$CARDANO_NETWORK" in
        mainnet) 
          is_mainnet=true
          network_flag_args=("--mainnet")
          ;;
        preprod) network_flag_args=("--testnet-magic" "1") ;;
        preview) network_flag_args=("--testnet-magic" "2") ;;
        sanchonet) network_flag_args=("--testnet-magic" "4") ;;
      esac
    fi
  fi
  
  # Block mainnet connections for external nodes
  if [ "$NODE_MODE" = "external" ] && [ "$is_mainnet" = true ]; then
    echo "Error: Mainnet connections are not allowed. Please use testnet networks (preprod, preview, sanchonet) only." >&2
    exit 1
  fi
  
  if [ "$NODE_MODE" = "external" ]; then
    # External node mode: use local cardano-cli with socket
    # Set socket path via environment variable (works with all cardano-cli versions)
    CARDANO_NODE_SOCKET_PATH="$NODE_SOCKET_PATH" cardano-cli "${network_flag_args[@]}" "$@"
  else
    # Docker mode: execute inside container
    local container_name=$(get_container_name)
    if [ -z "$container_name" ]; then
      echo "Error: Failed to determine a running container." >&2
      exit 1
    fi
    docker exec -ti "$container_name" cardano-cli "${network_flag_args[@]}" "$@"
  fi
}

# Call version check when wrapper is sourced
check_cardano_cli_version

