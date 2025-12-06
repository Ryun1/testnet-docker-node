#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# Load configuration for node connection
# Sets: NODE_MODE, NODE_SOCKET_PATH, CARDANO_NETWORK, CARDANO_NODE_NETWORK_ID
# 
# Priority:
# 1. CARDANO_CONTAINER_NAME (explicit container selection)
# 2. CARDANO_FORCE_DOCKER=true (force Docker mode)
# 3. Interactive selection if both Docker containers and external socket are available
# 4. External node: CARDANO_NODE_SOCKET_PATH + CARDANO_NODE_NETWORK_ID (environment variables)
# 5. Docker mode: Auto-select container (default)

# Check for explicit container name (highest priority)
if [ -n "${CARDANO_CONTAINER_NAME:-}" ]; then
  export NODE_MODE="docker"
  return 0
fi

# Check for force Docker mode
if [ "${CARDANO_FORCE_DOCKER:-}" = "true" ] || [ "${CARDANO_FORCE_DOCKER:-}" = "1" ]; then
  export NODE_MODE="docker"
  return 0
fi

# Check if docker-compose.yml exists (indicates Docker setup is expected)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd "$script_dir/../.." && pwd)"
docker_compose_file="$base_dir/docker-compose.yml"

# Get running containers
running_containers=""
if command -v docker &> /dev/null; then
  running_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E '^node-' || true)
fi

# Safety check: If docker-compose.yml exists but no containers are running and no socket is set,
# user probably forgot to start Docker
if [ -f "$docker_compose_file" ] && [ -z "$running_containers" ] && [ -z "${CARDANO_NODE_SOCKET_PATH:-}" ]; then
  echo "Error: Docker setup detected (docker-compose.yml exists) but no containers are running." >&2
  echo "Please start your Docker containers first:" >&2
  echo "  ./start-node.sh" >&2
  exit 1
fi

# Check if we need interactive selection
# This happens when both Docker containers and external socket are available
if [ -n "${CARDANO_NODE_SOCKET_PATH:-}" ] && [ -n "$running_containers" ]; then
    # Both Docker containers and external socket are available - let user choose
    # Check if we're in an interactive terminal
    if [ -t 0 ] && [ -t 1 ]; then
      echo -e "${CYAN}Multiple node options available:${NC}" >&2
      echo "" >&2
      
      # Build container array
      container_array=()
      while IFS= read -r container; do
        [ -n "$container" ] && container_array+=("$container")
      done <<< "$running_containers"
      
      socket_path="${CARDANO_NODE_SOCKET_PATH/#\~/$HOME}"
      
      # Display colored options
      option_num=1
      for container in "${container_array[@]}"; do
        echo -e "${BLUE}  $option_num) ${GREEN}Docker:${NC} $container" >&2
        option_num=$((option_num + 1))
      done
      echo -e "${BLUE}  $option_num) ${YELLOW}External:${NC} $socket_path" >&2
      echo "" >&2
      echo -e "${CYAN}Select which node to use:${NC}" >&2
      
      # Build plain options array for selection
      options=()
      for container in "${container_array[@]}"; do
        options+=("docker:$container")
      done
      options+=("external:$socket_path")
      
      # Prompt user with colored prompt
      while true; do
        echo -ne "${CYAN}#? ${NC}" >&2
        read -r selection < /dev/tty
        
        # Validate input
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#options[@]} ]; then
          echo -e "${RED}Invalid selection. Please enter a number between 1 and ${#options[@]}.${NC}" >&2
          continue
        fi
        
        # Get selected option (convert to 0-based index)
        selected_index=$((selection - 1))
        choice="${options[$selected_index]}"
        
        if [[ "$choice" == docker:* ]]; then
          # User selected Docker container
          selected_container="${choice#docker:}"
          export CARDANO_CONTAINER_NAME="$selected_container"
          export NODE_MODE="docker"
          echo -e "${GREEN}Selected: Docker: $selected_container${NC}" >&2
          return 0
        elif [[ "$choice" == external:* ]]; then
          # User selected external node - continue with external node setup below
          break
        fi
      done
    fi
fi

# Check for external node configuration (environment variables)
# External nodes use CARDANO_NODE_SOCKET_PATH and CARDANO_NODE_NETWORK_ID
if [ -n "${CARDANO_NODE_SOCKET_PATH:-}" ]; then
  # Expand ~ to home directory
  socket_path="${CARDANO_NODE_SOCKET_PATH/#\~/$HOME}"
  
  # Validate socket file exists first
  if [ ! -S "$socket_path" ] && [ ! -f "$socket_path" ]; then
    echo "Error: Socket file '$socket_path' does not exist or is not accessible." >&2
    echo "Please check that CARDANO_NODE_SOCKET_PATH points to a valid socket file." >&2
    exit 1
  fi
  
  # If no containers are running but socket is set and valid, ask for confirmation
  if [ -z "$running_containers" ]; then
    # Check if we're in an interactive terminal
    if [ -t 0 ] && [ -t 1 ]; then
      echo -e "${YELLOW}No Docker containers are running, but external socket path is configured:${NC}" >&2
      echo -e "${BLUE}  $socket_path${NC}" >&2
      echo "" >&2
      echo -e "${CYAN}Do you want to use this external node? (y/n):${NC}" >&2
      read -r confirm < /dev/tty
      if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}Cancelled. Please start Docker containers or unset CARDANO_NODE_SOCKET_PATH.${NC}" >&2
        exit 0
      fi
    else
      # Non-interactive mode - can't ask for confirmation, so error out
      echo -e "${RED}Error: No Docker containers are running and external socket is configured.${NC}" >&2
      echo -e "${YELLOW}Cannot prompt for confirmation in non-interactive mode.${NC}" >&2
      echo -e "${YELLOW}Please start Docker containers or run in an interactive terminal.${NC}" >&2
      exit 1
    fi
  fi
  
  # Validate socket file extension
  if [[ "$socket_path" != *.socket ]]; then
    echo "Warning: Socket file should have .socket extension: $socket_path" >&2
  fi
  
  export NODE_MODE="external"
  export NODE_SOCKET_PATH="$socket_path"
  
  # CARDANO_NODE_NETWORK_ID must be set for external nodes
  if [ -z "${CARDANO_NODE_NETWORK_ID:-}" ]; then
    echo "Error: CARDANO_NODE_NETWORK_ID must be set when using CARDANO_NODE_SOCKET_PATH" >&2
    exit 1
  fi
  
  # Validate network ID is numeric
  if ! [[ "${CARDANO_NODE_NETWORK_ID:-}" =~ ^[0-9]+$ ]]; then
    echo "Error: CARDANO_NODE_NETWORK_ID must be a number." >&2
    exit 1
  fi
  
  export CARDANO_NODE_NETWORK_ID
  
  # Block mainnet for external nodes
  if [ "${CARDANO_NODE_NETWORK_ID:-}" = "764824073" ]; then
    echo "Error: Mainnet connections via external sockets are not allowed for security reasons." >&2
    echo "Please use Docker mode for mainnet, or set CARDANO_NODE_NETWORK_ID to a testnet value (1, 2, or 4)." >&2
    exit 1
  fi
  
  # Derive CARDANO_NETWORK from network ID if not set
  if [ -z "${CARDANO_NETWORK:-}" ]; then
    case "${CARDANO_NODE_NETWORK_ID:-}" in
      764824073) export CARDANO_NETWORK="mainnet" ;;
      1) export CARDANO_NETWORK="preprod" ;;
      2) export CARDANO_NETWORK="preview" ;;
      4) export CARDANO_NETWORK="sanchonet" ;;
    esac
  else
    export CARDANO_NETWORK
  fi
  return 0
fi

# Default to Docker mode (will auto-select container)
export NODE_MODE="docker"

