#!/bin/bash
set -euo pipefail

# Compile PV11 Plutus validators using Scalus 0.15.0
# Outputs .plutus TextEnvelope JSON files to ../plutus/pv11/

script_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$script_dir"

if ! command -v sbt &> /dev/null; then
  echo "Error: sbt not found. Install sbt to compile Scalus validators."
  echo "See https://www.scala-sbt.org/download/"
  exit 1
fi

output_dir="../plutus/pv11"
mkdir -p "$output_dir"

echo "Compiling PV11 validators with Scalus..."
sbt "run $output_dir"

echo ""
echo "Compiled validators:"
ls -la "$output_dir/"*.plutus
