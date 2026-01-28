#!/usr/bin/env bash
# Claude Code Model Switcher
# Convenient CLI for switching between Claude Code models
# Compatible with bash 3.2+ (macOS default)

set -eo pipefail

# ============================================
# Configuration
# ============================================

VERSION="1.0.0"
SCRIPT_NAME="$(basename "$0")"

# Claude Code config directory
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CLAUDE_SETTINGS_FILE="$CLAUDE_CONFIG_DIR/settings.json"

# ============================================
# Colors
# ============================================

color_reset='\033[0m'
color_bold='\033[1m'
color_green='\033[32m'
color_blue='\033[34m'
color_yellow='\033[33m'
color_red='\033[31m'

# ============================================
# Utility Functions
# ============================================

log_info() {
    echo -e "${color_blue}ℹ${color_reset} $*"
}

log_success() {
    echo -e "${color_green}✓${color_reset} $*"
}

log_warn() {
    echo -e "${color_yellow}⚠${color_reset} $*"
}

log_error() {
    echo -e "${color_red}✗${color_reset} $*" >&2
}

# ============================================
# Model Management
# ============================================

get_model_for_alias() {
    local alias="${1:-}"
    case "$alias" in
        claude)          echo "claude-opus-4-5-20251101" ;;
        claude-opus)     echo "claude-opus-4-5-20251101" ;;
        claude-sonnet)   echo "claude-sonnet-4-5-20250515" ;;
        claude-haiku)    echo "claude-haiku-4-5-20250114" ;;
        claude-glm)      echo "glm-4.7" ;;
        claude-kimi)     echo "kimi-k2.5" ;;
        *)               echo "" ;;
    esac
}

get_current_model() {
    if [[ -f "$CLAUDE_SETTINGS_FILE" ]]; then
        if command -v jq &>/dev/null; then
            jq -r '.defaultModel // "default"' "$CLAUDE_SETTINGS_FILE" 2>/dev/null || echo "default"
        else
            grep -o '"defaultModel"[[:space:]]*:[[:space:]]*"[^"]*"' "$CLAUDE_SETTINGS_FILE" 2>/dev/null | sed 's/.*"defaultModel"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo "default"
        fi
    else
        echo "default"
    fi
}

set_model() {
    local model="${1:-}"

    # Create config directory if it doesn't exist
    mkdir -p "$CLAUDE_CONFIG_DIR"

    # Create or update settings.json
    if [[ -f "$CLAUDE_SETTINGS_FILE" ]]; then
        if command -v jq &>/dev/null; then
            tmp_file=$(mktemp)
            jq --arg model "$model" '.defaultModel = $model' "$CLAUDE_SETTINGS_FILE" > "$tmp_file"
            mv "$tmp_file" "$CLAUDE_SETTINGS_FILE"
        else
            # Fallback without jq
            if grep -q '"defaultModel"' "$CLAUDE_SETTINGS_FILE"; then
                sed -i.bak "s/\"defaultModel\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"defaultModel\": \"$model\"/" "$CLAUDE_SETTINGS_FILE"
            else
                # Add defaultModel to existing JSON
                sed -i.bak "s/{/{\"defaultModel\": \"$model\", /" "$CLAUDE_SETTINGS_FILE"
            fi
        fi
    else
        echo "{\"defaultModel\": \"$model\"}" > "$CLAUDE_SETTINGS_FILE"
    fi

    log_success "Default model set to: ${color_bold}$model${color_reset}"
}

list_models() {
    local current model alias
    current=$(get_current_model)

    echo -e "\n${color_bold}Available Model Presets:${color_reset}\n"

    # List all models
    for alias in claude claude-opus claude-sonnet claude-haiku claude-glm claude-kimi; do
        model=$(get_model_for_alias "$alias")
        local is_current=""
        if [[ "${model:-}" == "${current:-}" ]]; then
            is_current="${color_green} [CURRENT]${color_reset}"
        fi
        if [[ "$alias" == "claude" ]]; then
            echo -e "  ${color_green}${alias}${color_reset} → $model${is_current}"
        else
            echo -e "  ${color_blue}${alias}${color_reset} → $model${is_current}"
        fi
    done
    echo ""
    echo -e "Current default model: ${color_bold}${current:-default}${color_reset}"
    echo ""
}

# ============================================
# Claude Code Execution
# ============================================

run_claude_code() {
    local model="${1:-}"
    shift || true

    # Set the model before running
    set_model "$model"

    # Run Claude Code with remaining arguments
    log_info "Starting Claude Code with model: ${color_bold}$model${color_reset}"

    if command -v claude &>/dev/null; then
        exec claude "$@"
    elif [[ -f "/usr/local/bin/claude" ]]; then
        exec /usr/local/bin/claude "$@"
    elif [[ -f "$HOME/.local/bin/claude" ]]; then
        exec "$HOME/.local/bin/claude" "$@"
    else
        log_error "Claude Code not found. Please install it first:"
        echo "  npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
}

# ============================================
# Command Handlers
# ============================================

cmd_current() {
    local current
    current=$(get_current_model)
    echo "Current default model: ${color_bold}${current:-default}${color_reset}"
}

cmd_list() {
    list_models
}

cmd_set() {
    local model="${1:-}"

    if [[ -z "${model:-}" ]]; then
        log_error "Model name required"
        echo "Usage: $SCRIPT_NAME set <model-name>"
        exit 1
    fi

    set_model "$model"
}

cmd_use() {
    local alias_or_model="${1:-}"
    local model
    shift || true

    if [[ -z "${alias_or_model:-}" ]]; then
        log_error "Model alias or name required"
        echo "Usage: $SCRIPT_NAME use <model-alias|model-name>"
        exit 1
    fi

    # Check if it's a preset alias
    model=$(get_model_for_alias "$alias_or_model")

    if [[ -z "${model:-}" ]]; then
        # Use as-is (custom model)
        model="$alias_or_model"
    fi

    run_claude_code "$model" "$@"
}

cmd_help() {
    cat << EOF
${color_bold}Claude Code Model Switcher${color_reset} v${VERSION}

${color_bold}USAGE${color_reset}
    $SCRIPT_NAME <command> [options]

${color_bold}COMMANDS${color_reset}
    ${color_green}current${color_reset}           Show current default model
    ${color_green}list${color_reset}              List all available model presets
    ${color_green}set${color_reset} <model>       Set default model (without running)
    ${color_green}use${color_reset} <alias|model> Run Claude Code with specified model
    ${color_green}help${color_reset}              Show this help message

${color_bold}MODEL ALIASES${color_reset}
EOF
    list_models

    cat << EOF
${color_bold}EXAMPLES${color_reset}
    $SCRIPT_NAME current              # Show current model
    $SCRIPT_NAME list                 # List all presets
    $SCRIPT_NAME use claude           # Run with default (Opus)
    $SCRIPT_NAME use claude-glm       # Run with GLM 4.7
    $SCRIPT_NAME use claude-sonnet    # Run with Sonnet
    $SCRIPT_NAME use glm-4.7          # Run with custom model

${color_bold}QUICK ALIASES${color_reset}
    You can also use direct commands:
    ${color_blue}claude${color_reset}          # Same as: $SCRIPT_NAME use claude
    ${color_blue}claude-glm${color_reset}      # Same as: $SCRIPT_NAME use claude-glm
    ${color_blue}claude-kimi${color_reset}     # Same as: $SCRIPT_NAME use claude-kimi
    ${color_blue}claude-opus${color_reset}     # Same as: $SCRIPT_NAME use claude-opus
    ${color_blue}claude-sonnet${color_reset}   # Same as: $SCRIPT_NAME use claude-sonnet
    ${color_blue}claude-haiku${color_reset}    # Same as: $SCRIPT_NAME use claude-haiku

${color_bold}KIMI SETUP${color_reset}
    To use claude-kimi, set up environment variables:
    ${color_yellow}export ANTHROPIC_AUTH_TOKEN=sk-YOURKEY${color_reset}
    ${color_yellow}export ANTHROPIC_BASE_URL=https://api.moonshot.ai/anthropic${color_reset}
    Get your key at: https://platform.moonshot.ai/

EOF
}

# ============================================
# Main Entry Point
# ============================================

main() {
    local command="${1:-}"
    shift || true

    case "$command" in
        current)
            cmd_current
            ;;
        list|ls)
            cmd_list
            ;;
        set)
            cmd_set "$@"
            ;;
        use|--use|-u)
            cmd_use "$@"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        "")
            # No command = run with default model
            run_claude_code "$(get_model_for_alias claude)"
            ;;
        *)
            # Treat as model alias/name
            cmd_use "$command" "$@"
            ;;
    esac
}

main "$@"
