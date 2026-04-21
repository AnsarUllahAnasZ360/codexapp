#!/usr/bin/env bash

# FILE: run-local-mobidex.sh
# Purpose: White-label local launcher for the Mobidex relay + bridge flow.
# Layer: developer utility
# Exports: none
# Depends on: run-local-remodex.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${ROOT_DIR}/run-local-remodex.sh" "$@"
