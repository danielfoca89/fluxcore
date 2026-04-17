#!/usr/bin/env bats
# ==============================================================================
# FluxCore — Constants Library Tests
# Tests for lib/constants.sh
# ==============================================================================

setup() {
    source "${BATS_TEST_DIRNAME}/test_helper.sh"
}

@test "constants: FLUXCORE_VERSION is set" {
    [ -n "$FLUXCORE_VERSION" ]
}

@test "constants: color codes are defined" {
    [ -n "$FC_RED" ]
    [ -n "$FC_GREEN" ]
    [ -n "$FC_YELLOW" ]
    [ -n "$FC_BLUE" ]
    [ -n "$FC_CYAN" ]
    [ -n "$FC_NC" ]
}

@test "constants: backward-compatible color aliases match" {
    [ "$RED" = "$FC_RED" ]
    [ "$GREEN" = "$FC_GREEN" ]
    [ "$YELLOW" = "$FC_YELLOW" ]
    [ "$NC" = "$FC_NC" ]
}

@test "constants: paths are set" {
    [ -n "$FLUXCORE_SECRETS_DIR" ]
    [ -n "$FLUXCORE_LOG_DIR" ]
    [ -n "$FLUXCORE_AUDIT_LOG" ]
}

@test "constants: double-sourcing guard works" {
    # Source again — should not error
    source "${FLUXCORE_ROOT}/lib/constants.sh"
    [ -n "$FLUXCORE_VERSION" ]
}
