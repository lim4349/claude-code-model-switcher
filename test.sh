#!/usr/bin/env bash
# Claude Code Model Switcher Test Suite

set -uo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_SCRIPT="$SCRIPT_DIR/claude-code-model-switcher.sh"
TEST_DIR="$(mktemp -d)"
CLAUDE_TEST_DIR="$TEST_DIR/.claude"

# Colors
color_reset='\033[0m'
color_bold='\033[1m'
color_green='\033[32m'
color_blue='\033[34m'
color_yellow='\033[33m'
color_red='\033[31m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================
# Test Framework
# ============================================

log_info() {
    echo -e "${color_blue}ℹ${color_reset} $*"
}

log_success() {
    echo -e "${color_green}✓${color_reset} $*"
}

log_error() {
    echo -e "${color_red}✗${color_reset} $*" >&2
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$expected" == "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "${message:-Assertion passed}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "${message:-Assertion failed}"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$haystack" == *"$needle"* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "${message:-Assertion passed}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "${message:-Assertion failed}"
        echo "  String does not contain: $needle"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File exists: $file}"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -f "$file" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "$message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "File does not exist: $file"
        return 1
    fi
}

# ============================================
# Setup/Teardown
# ============================================

setup() {
    log_info "Setting up test environment..."
    mkdir -p "$CLAUDE_TEST_DIR"
    export CLAUDE_CONFIG_DIR="$CLAUDE_TEST_DIR"
}

teardown() {
    log_info "Cleaning up..."
    rm -rf "$TEST_DIR"
}

# ============================================
# Test Cases
# ============================================

test_script_executable() {
    log_info "Testing: Script is executable..."

    [[ -x "$TEST_SCRIPT" ]]
    assert_equals "0" "$?" "Script should be executable"
}

test_help_command() {
    log_info "Testing: Help command..."

    local output
    output=$("$TEST_SCRIPT" help 2>&1)

    assert_contains "$output" "Claude Code Model Switcher" "Help should show title"
    assert_contains "$output" "USAGE" "Help should show usage"
    assert_contains "$output" "COMMANDS" "Help should show commands"
}

test_list_command() {
    log_info "Testing: List command..."

    local output
    output=$("$TEST_SCRIPT" list 2>&1)

    assert_contains "$output" "claude" "List should show claude alias"
    assert_contains "$output" "claude-glm" "List should show claude-glm alias"
    assert_contains "$output" "claude-kimi" "List should show claude-kimi alias"
    assert_contains "$output" "claude-deepseek" "List should show claude-deepseek alias"
    assert_contains "$output" "claude-opus" "List should show claude-opus alias"
}

test_current_command() {
    log_info "Testing: Current command..."

    local output
    output=$("$TEST_SCRIPT" current 2>&1)

    assert_contains "$output" "Current default model" "Should show current model"
}

test_set_command() {
    log_info "Testing: Set command..."

    "$TEST_SCRIPT" set claude-opus-4-6 &>/dev/null

    local output
    output=$("$TEST_SCRIPT" current 2>&1)

    assert_contains "$output" "claude-opus-4-6" "Model should be set"
}

test_settings_file_creation() {
    log_info "Testing: Settings file creation..."

    "$TEST_SCRIPT" set claude-sonnet-4-5-20250515 &>/dev/null

    assert_file_exists "$CLAUDE_TEST_DIR/settings.json" "Settings file should be created"

    local content
    content=$(cat "$CLAUDE_TEST_DIR/settings.json")

    assert_contains "$content" "claude-sonnet-4-5-20250515" "Settings should contain model"
}

test_model_presets() {
    log_info "Testing: Model presets..."

    local expected_presets=("claude" "claude-opus" "claude-sonnet" "claude-haiku" "claude-glm" "claude-kimi" "claude-deepseek" "claude-qwen" "claude-minimax" "claude-openrouter")

    for preset in "${expected_presets[@]}"; do
        local output
        output=$("$TEST_SCRIPT" list 2>&1)
        assert_contains "$output" "$preset" "List should contain preset: $preset"
    done
}

# ============================================
# Test Runner
# ============================================

run_all_tests() {
    echo ""
    echo -e "${color_bold}${color_blue}Running Claude Code Model Switcher Tests${color_reset}"
    echo ""

    setup

    test_script_executable
    test_help_command
    test_list_command
    test_current_command
    test_set_command
    test_settings_file_creation
    test_model_presets

    teardown

    echo ""
    echo -e "${color_bold}${color_blue}═══════════════════════════════════════${color_reset}"
    echo -e "${color_bold}${color_blue}  Test Results${color_reset}"
    echo -e "${color_bold}${color_blue}═══════════════════════════════════════${color_reset}"
    echo ""
    echo -e "  Tests Run:    ${color_bold}$TESTS_RUN${color_reset}"
    echo -e "  ${color_green}Tests Passed: ${color_green}$TESTS_PASSED${color_reset}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "  ${color_red}Tests Failed: ${color_red}$TESTS_FAILED${color_reset}"
    else
        echo -e "  Tests Failed: $TESTS_FAILED"
    fi
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        return 0
    else
        log_error "Some tests failed!"
        return 1
    fi
}

# ============================================
# Main Entry Point
# ============================================

main() {
    run_all_tests
}

main "$@"
