#!/usr/bin/env bash
set -Eeuo pipefail

command -v vault &>/dev/null && exit 0 || exit 1
