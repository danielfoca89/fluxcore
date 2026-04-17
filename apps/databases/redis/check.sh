#!/usr/bin/env bash
# ==============================================================================
# FluxCore — Redis Check  (READ-ONLY)
# Returns 0 if Redis is installed and running (native), 1 otherwise.
# IMPORTANT: Must NOT call sudo or start services — this runs during menu build.
# ==============================================================================
set -Eeuo pipefail

# Must have either redis-server or redis-cli
command -v redis-server &>/dev/null || command -v redis-cli &>/dev/null || exit 1

# Passive status check only — no service starting
systemctl is-active --quiet redis-server 2>/dev/null && exit 0
systemctl is-active --quiet redis 2>/dev/null && exit 0
exit 1
