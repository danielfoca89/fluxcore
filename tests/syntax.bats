#!/usr/bin/env bats
# ==============================================================================
# FluxCore — Syntax Validation Tests
# Ensures all shell scripts parse without syntax errors
# ==============================================================================

@test "all scripts pass bash -n syntax check" {
    local errors=0
    while IFS= read -r script; do
        if ! bash -n "$script" 2>/dev/null; then
            echo "SYNTAX ERROR: $script" >&2
            errors=$((errors + 1))
        fi
    done < <(find "${BATS_TEST_DIRNAME}/.." -name '*.sh' -type f -not -path '*/.git/*')

    [ "$errors" -eq 0 ]
}

@test "all scripts have #!/usr/bin/env bash shebang" {
    local errors=0
    while IFS= read -r script; do
        local first_line
        first_line=$(head -1 "$script")
        if [[ "$first_line" != "#!/usr/bin/env bash" ]]; then
            echo "BAD SHEBANG ($first_line): $script" >&2
            errors=$((errors + 1))
        fi
    done < <(find "${BATS_TEST_DIRNAME}/.." -name '*.sh' -type f -not -path '*/.git/*' -not -path '*/test_helper.sh')

    [ "$errors" -eq 0 ]
}
