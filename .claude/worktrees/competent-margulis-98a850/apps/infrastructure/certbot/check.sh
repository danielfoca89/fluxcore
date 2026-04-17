#!/usr/bin/env bash
set -Eeuo pipefail

command -v certbot &>/dev/null && exit 0 || exit 1
