#!/usr/bin/env bash
# ==============================================================================
# FluxCore — Nginx Check  (READ-ONLY)
# Returns 0 if Nginx is installed and running, 1 otherwise.
# IMPORTANT: Must NOT call sudo or start services — this runs during menu build.
# ==============================================================================
set -Eeuo pipefail

command -v nginx &>/dev/null || exit 1

# Passive status check only — no service starting
systemctl is-active --quiet nginx 2>/dev/null && exit 0
exit 1
