#!/usr/bin/env bash
# ==============================================================================
# FluxCore — bats-core test helper
# Sources all FluxCore libraries for use in tests
# ==============================================================================

# Resolve project root from tests/ directory
FLUXCORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FLUXCORE_ROOT

# Source the library auto-loader
source "${FLUXCORE_ROOT}/lib/constants.sh"

# Load only safe-to-test libraries (skip set -e for test compatibility)
# Individual tests can source additional libraries as needed
