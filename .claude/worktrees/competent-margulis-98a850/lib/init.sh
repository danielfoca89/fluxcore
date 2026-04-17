#!/usr/bin/env bash

# ==============================================================================
# FLUXCORE — LIBRARY AUTO-LOADER
# Sources all FluxCore libraries and initializes the environment.
# Usage: source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/init.sh"
#   or from any depth: source "${FLUXCORE_ROOT}/lib/init.sh"
# ==============================================================================

# Prevent double-sourcing
[[ -n "${_FLUXCORE_INIT_LOADED:-}" ]] && return 0
readonly _FLUXCORE_INIT_LOADED=1

# --- Resolve FLUXCORE_ROOT ---
# Works regardless of how deeply nested the calling script is.
FLUXCORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly FLUXCORE_ROOT
export FLUXCORE_ROOT

# --- Source all libraries in dependency order ---
# shellcheck source=lib/constants.sh
source "${FLUXCORE_ROOT}/lib/constants.sh"

# shellcheck source=lib/utils.sh
source "${FLUXCORE_ROOT}/lib/utils.sh"

# shellcheck source=lib/os-detect.sh
source "${FLUXCORE_ROOT}/lib/os-detect.sh"

# shellcheck source=lib/docker.sh
source "${FLUXCORE_ROOT}/lib/docker.sh"

# shellcheck source=lib/secrets.sh
source "${FLUXCORE_ROOT}/lib/secrets.sh"

# shellcheck source=lib/preflight.sh
source "${FLUXCORE_ROOT}/lib/preflight.sh"

# --- Ensure OS is detected ---
# os-detect.sh auto-detects on source, but we ensure it here as a safety net.
if [[ -z "${OS_ID:-}" ]]; then
    detect_os
fi

# --- Expose SCRIPT_DIR for backward compatibility ---
# Many scripts define their own SCRIPT_DIR. If not already set by the caller,
# we set it to FLUXCORE_ROOT so library functions that reference SCRIPT_DIR work.
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="${FLUXCORE_ROOT}"
    export SCRIPT_DIR
fi
