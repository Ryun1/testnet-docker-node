#!/bin/bash

# Amaru Start Helper Script
# Helper script for starting Amaru nodes with proper configuration

set -euo pipefail

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# Get script directory
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base_dir="$(cd "$script_dir/../.." && pwd)"

echo -e "${CYAN}Amaru Node Start Helper${NC}"
echo ""
echo -e "${BLUE}This script is a helper for Amaru node operations.${NC}"
echo -e "${BLUE}For starting Amaru nodes, use the main start-node.sh script:${NC}"
echo -e "${YELLOW}  ./start-node.sh${NC}"
echo ""
echo -e "${BLUE}Then select 'Amaru' as the node type when prompted.${NC}"

