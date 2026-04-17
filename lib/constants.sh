#!/usr/bin/env bash

# ==============================================================================
# FLUXCORE — SHARED CONSTANTS
# Readonly values used across all FluxCore scripts
# ==============================================================================

# Prevent double-sourcing
[[ -n "${_FLUXCORE_CONSTANTS_LOADED:-}" ]] && return 0
readonly _FLUXCORE_CONSTANTS_LOADED=1

# --- VERSION ---
# Version is determined dynamically from git tags or fallback.
# Version control is handled exclusively by .github workflows and release-please.
readonly FLUXCORE_VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "dev")

# --- TERMINAL COLORS ---
readonly FC_RED='\033[0;31m'
readonly FC_GREEN='\033[0;32m'
readonly FC_YELLOW='\033[1;33m'
readonly FC_BLUE='\033[0;34m'
readonly FC_CYAN='\033[0;36m'
readonly FC_MAGENTA='\033[0;35m'
readonly FC_NC='\033[0m' # No Color

# Backward-compatible aliases (these match existing scripts)
RED="${FC_RED}"
GREEN="${FC_GREEN}"
YELLOW="${FC_YELLOW}"
BLUE="${FC_BLUE}"
CYAN="${FC_CYAN}"
MAGENTA="${FC_MAGENTA}"
NC="${FC_NC}"

# --- PATHS ---
readonly FLUXCORE_SECRETS_DIR="${HOME}/.vps-secrets"
readonly FLUXCORE_LOG_DIR="${HOME}/.flux-orchestrator/logs"
readonly FLUXCORE_AUDIT_LOG="${FLUXCORE_SECRETS_DIR}/.audit.log"
