#!/usr/bin/env bats
# ==============================================================================
# FluxCore — Init Library Tests
# Tests for lib/init.sh auto-loader
# ==============================================================================

setup() {
    # Source init.sh directly (it will load all libraries)
    FLUXCORE_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export FLUXCORE_ROOT
    source "${FLUXCORE_ROOT}/lib/init.sh"
}

@test "init: FLUXCORE_ROOT is set correctly" {
    [ -d "$FLUXCORE_ROOT" ]
    [ -f "$FLUXCORE_ROOT/lib/init.sh" ]
}

@test "init: all library guards are loaded" {
    [ "$_FLUXCORE_INIT_LOADED" = "1" ]
    [ "$_FLUXCORE_CONSTANTS_LOADED" = "1" ]
    [ "$_FLUXCORE_UTILS_LOADED" = "1" ]
    [ "$_FLUXCORE_OS_DETECT_LOADED" = "1" ]
}

@test "init: logging functions are available" {
    # These should be defined from utils.sh
    declare -f log_info >/dev/null
    declare -f log_warn >/dev/null
    declare -f log_error >/dev/null
    declare -f log_success >/dev/null
    declare -f log_step >/dev/null
}

@test "init: SCRIPT_DIR fallback is set" {
    [ -n "$SCRIPT_DIR" ]
    [ -d "$SCRIPT_DIR" ]
}

@test "init: double-sourcing guard works" {
    source "${FLUXCORE_ROOT}/lib/init.sh"
    [ "$_FLUXCORE_INIT_LOADED" = "1" ]
}
