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
    printf "%bℹ%b %s\n" "${color_blue}" "${color_reset}" "$*"
}

log_success() {
    printf "%b✓%b %s\n" "${color_green}" "${color_reset}" "$*"
}

log_warn() {
    printf "%b⚠%b %s\n" "${color_yellow}" "${color_reset}" "$*"
}

log_error() {
    printf "%b✗%b %s\n" "${color_red}" "${color_reset}" "$*" >&2
}

# ============================================
# Provider Settings (gist-compatible)
# ============================================

_settings_file_for_provider() {
    local provider="${1:-}"
    case "$provider" in
        glm)  echo "$CLAUDE_CONFIG_DIR/zai_settings.json" ;;
        kimi) echo "$CLAUDE_CONFIG_DIR/kimi_settings.json" ;;
        *)    echo "" ;;
    esac
}

_base_url_for_provider() {
    local provider="${1:-}"
    case "$provider" in
        glm)  echo "https://api.z.ai/api/anthropic" ;;
        # Kimi Claude-Code compatible endpoint (per user requirement)
        kimi) echo "https://api.kimi.com/coding/" ;;
        *)    echo "" ;;
    esac
}

_model_for_provider() {
    local provider="${1:-}"
    case "$provider" in
        glm)  echo "glm-4.7" ;;
        kimi) echo "kimi-k2.5" ;;
        *)    echo "" ;;
    esac
}

_read_existing_token_from_settings() {
    local settings_file="${1:-}"
    [[ -f "$settings_file" ]] || return 0

    if command -v jq >/dev/null 2>&1; then
        jq -r '.env.ANTHROPIC_API_KEY // .env.ANTHROPIC_AUTH_TOKEN // empty' "$settings_file" 2>/dev/null || true
        return 0
    fi

    # Fallback without jq: simple string extraction
    local v=""
    v="$(grep -o '\"ANTHROPIC_API_KEY\"[[:space:]]*:[[:space:]]*\"[^\"]*\"' "$settings_file" 2>/dev/null \
        | sed 's/.*"ANTHROPIC_API_KEY"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' \
        | head -n 1)"
    if [[ -n "${v:-}" ]]; then
        echo "$v"
        return 0
    fi
    grep -o '\"ANTHROPIC_AUTH_TOKEN\"[[:space:]]*:[[:space:]]*\"[^\"]*\"' "$settings_file" 2>/dev/null \
        | sed 's/.*"ANTHROPIC_AUTH_TOKEN"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' \
        | head -n 1
}

_read_existing_value_from_settings() {
    local settings_file="${1:-}"
    local key="${2:-}" # e.g. ANTHROPIC_BASE_URL / ANTHROPIC_MODEL
    [[ -f "$settings_file" ]] || return 0

    if command -v jq >/dev/null 2>&1; then
        jq -r --arg k "$key" '.env[$k] // empty' "$settings_file" 2>/dev/null || true
        return 0
    fi

    grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$settings_file" 2>/dev/null \
        | sed "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/" \
        | head -n 1
}

_write_provider_settings() {
    local provider="${1:-}"
    local token="${2:-}"
    local base_url_override="${3:-}"
    local model_override="${4:-}"

    local settings_file base_url model
    settings_file="$(_settings_file_for_provider "$provider")"
    base_url="${base_url_override:-$(_base_url_for_provider "$provider")}"
    model="${model_override:-$(_model_for_provider "$provider")}"

    if [[ -z "${settings_file:-}" || -z "${base_url:-}" || -z "${model:-}" ]]; then
        log_error "Unknown provider: $provider"
        return 1
    fi

    mkdir -p "$CLAUDE_CONFIG_DIR"

    local auth_key_name="ANTHROPIC_AUTH_TOKEN"
    if [[ "$provider" == "kimi" ]]; then
        auth_key_name="ANTHROPIC_API_KEY"
    fi

    # For GLM, provide both glm-4.7 and glm-5 as available models
    local available_models="$model"
    if [[ "$provider" == "glm" ]]; then
        available_models="glm-4.7,glm-5"
    fi

    (umask 077
        cat > "$settings_file" << EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "$base_url",
    "$auth_key_name": "$token",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "ANTHROPIC_MODEL": "$model",
    "ANTHROPIC_SMALL_FAST_MODEL": "$model",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.7",
    "CLAUDE_CODE_SUBAGENT_MODEL": "glm-4.7",
    "CLAUDE_CODE_AVAILABLE_MODELS": "$available_models"
  }
}
EOF
    )

    chmod 600 "$settings_file" 2>/dev/null || true
    log_success "Saved: $settings_file"
}

_configure_provider_interactive() {
    local provider="${1:-}"
    local settings_file
    settings_file="$(_settings_file_for_provider "$provider")"

    local current_token=""
    current_token="$(_read_existing_token_from_settings "$settings_file" || true)"

    local default_base_url default_model
    default_base_url="$(_base_url_for_provider "$provider")"
    default_model="$(_model_for_provider "$provider")"

    local current_base_url current_model
    current_base_url="$(_read_existing_value_from_settings "$settings_file" "ANTHROPIC_BASE_URL" || true)"
    current_model="$(_read_existing_value_from_settings "$settings_file" "ANTHROPIC_MODEL" || true)"

    local token=""
    if [[ -n "${current_token:-}" ]]; then
        echo "Current API key: ${current_token:0:12}..."
        echo "Press Enter to keep it, or type a new key:"
        read -r -p "> " token
        if [[ -z "${token:-}" ]]; then
            token="$current_token"
        fi
    else
        echo "Enter API key (input hidden):"
        read -r -s -p "> " token
        echo ""
    fi

    if [[ -z "${token:-}" ]]; then
        log_warn "No API token provided"
        return 1
    fi

    local base_url model
    base_url="${current_base_url:-$default_base_url}"
    model="${current_model:-$default_model}"

    # Migration hint: older installs used Moonshot's endpoint for Kimi. Prefer the new default.
    if [[ "$provider" == "kimi" && "${base_url:-}" == *"moonshot.ai"* ]]; then
        base_url="$default_base_url"
    fi

    echo "Base URL (Enter to keep: $base_url):"
    read -r -p "> " input_url
    if [[ -n "${input_url:-}" ]]; then
        base_url="$input_url"
    fi

    echo "Model (Enter to keep: $model):"
    read -r -p "> " input_model
    if [[ -n "${input_model:-}" ]]; then
        model="$input_model"
    fi

    _write_provider_settings "$provider" "$token" "$base_url" "$model"
}

# ============================================
# Model Management
# ============================================

get_model_for_alias() {
    local alias="${1:-}"
    case "$alias" in
        claude)        echo "claude-sonnet-4-5-20250515" ;;
        claude-opus)   echo "claude-opus-4-6" ;;
        claude-sonnet) echo "claude-sonnet-4-5-20250515" ;;
        claude-haiku)  echo "claude-haiku-4-5-20250114" ;;
        claude-glm)    echo "glm-4.7" ;;
        claude-kimi)   echo "kimi-k2.5" ;;
        *)             echo "" ;;
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

    printf "\n%bAvailable Model Presets:%b\n\n" "${color_bold}" "${color_reset}"

    # List only supported models
    for alias in claude claude-opus claude-sonnet claude-haiku claude-glm claude-kimi; do
        model=$(get_model_for_alias "$alias")
        local is_current=""
        if [[ "${model:-}" == "${current:-}" ]]; then
            is_current=" ${color_green}[CURRENT]${color_reset}"
        fi
        if [[ "$alias" == "claude" ]]; then
            printf "  %b%s%b → %s%b\n" "${color_green}" "${alias}" "${color_reset}" "${model}" "${is_current}"
        else
            printf "  %b%s%b → %s%b\n" "${color_blue}" "${alias}" "${color_reset}" "${model}" "${is_current}"
        fi
    done
    printf "\nCurrent default model: %b%s%b\n\n" "${color_bold}" "${current:-default}" "${color_reset}"
}

# ============================================
# Claude Code Execution
# ============================================

# Find the real claude binary (not wrappers)
_find_claude_binary() {
    # Try npm global prefix first (works in all npm versions)
    if command -v npm &>/dev/null; then
        local npm_prefix
        npm_prefix=$(npm prefix -g 2>/dev/null || echo "")
        if [[ -n "$npm_prefix" && -f "$npm_prefix/bin/claude" ]]; then
            echo "$npm_prefix/bin/claude"
            return 0
        fi
    fi

    # Check common locations
    local locations=(
        "/usr/local/bin/claude"
        "/usr/bin/claude"
        "$HOME/.npm-global/bin/claude"
        "$HOME/.local/bin/claude"
    )

    for location in "${locations[@]}"; do
        if [[ -f "$location" ]]; then
            # Check if it's our wrapper (text file, starts with #!)
            if head -1 "$location" 2>/dev/null | grep -q "#!"; then
                # It's a script, check if it's our wrapper
                if grep -q "claude-model" "$location" 2>/dev/null; then
                    # Skip our wrapper
                    continue
                fi
            fi
            # It's a binary or non-wrapper script
            echo "$location"
            return 0
        fi
    done

    return 1
}

run_claude_code() {
    local model="${1:-}"
    shift || true

    # Set the model before running
    set_model "$model"

    # Run Claude Code with remaining arguments
    log_info "Starting Claude Code with model: ${color_bold}$model${color_reset}"

    local claude_bin
    claude_bin=$(_find_claude_binary)

    if [[ -n "$claude_bin" && -f "$claude_bin" ]]; then
        exec "$claude_bin" "$@"
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
    printf "Current default model: %b%s%b\n" "${color_bold}" "${current:-default}" "${color_reset}"
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

cmd_config() {
    local model_name="${1:-}"

    # If no model specified, show interactive menu (repeatable)
    if [[ -z "${model_name:-}" ]]; then
        while true; do
            echo -e "\n${color_bold}${color_blue}═══════════════════════════════════════════════════${color_reset}"
            echo -e "${color_bold}${color_blue}  Configure Provider Settings${color_reset}"
            echo -e "${color_bold}${color_blue}═══════════════════════════════════════════════════${color_reset}"
            echo ""
            echo -e "  ${color_green}1${color_reset}. glm   (GLM 4.7 & 5 / Z.ai)"
            echo -e "       - Use /model to switch between glm-4.7 and glm-5"
            echo -e "  ${color_green}2${color_reset}. kimi  (Kimi 2.5 / Moonshot)"
            echo -e "  ${color_green}3${color_reset}. exit"
            echo ""
            read -r -p "Select option (1-3): " choice

            case "$choice" in
                1) model_name="glm" ;;
                2) model_name="kimi" ;;
                3) return 0 ;;
                *) log_warn "Invalid selection" ; continue ;;
            esac

            cmd_config "$model_name" || true
            model_name=""
        done
    fi

    # Preferred path: write gist-compatible `*_settings.json` for supported providers
    case "$model_name" in
        glm|kimi)
            echo -e "${color_bold}Configuring: ${color_blue}${model_name}${color_reset}"
            _configure_provider_interactive "$model_name"
            echo ""
            echo -e "Now you can run:"
            case "$model_name" in
                glm)  echo -e "  ${color_blue}claude-glm${color_reset} (or ${color_blue}cluade-glm${color_reset})" ;;
                kimi) echo -e "  ${color_blue}claude-kimi${color_reset} (or ${color_blue}cluade-kimi${color_reset})" ;;
            esac
            return 0
            ;;
    esac

    # Legacy path (kept for compatibility): config.json via jq
    local config_file="$CLAUDE_CONFIG_DIR/config.json"

    # Get default base URL
    local default_url=""
    case "$model_name" in
        claude)      default_url="https://api.anthropic.com" ;;
        glm)         default_url="https://api.z.ai/api/anthropic" ;;
        kimi)        default_url="https://api.moonshot.ai/anthropic" ;;
        deepseek)    default_url="https://api.deepseek.com/anthropic" ;;
        qwen)        default_url="https://dashscope-intl.aliyuncs.com/apps/anthropic" ;;
        minimax)     default_url="https://api.minimax.io/anthropic" ;;
        openrouter)  default_url="https://openrouter.ai/api" ;;
        *)           default_url="" ;;
    esac

    echo -e "${color_bold}Configuring for model: ${color_blue}${model_name}${color_reset}"
    echo ""

    # Load existing config
    local current_token=""
    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        current_token=$(jq -r ".${model_name}.authToken // empty" "$config_file" 2>/dev/null)
    fi

    if [[ -n "$current_token" ]]; then
        echo "Current API key: ${current_token:0:15}..."
        echo "  Press Enter to keep, or type a new key:"
        read -p "> " -r token
        if [[ -z "$token" ]]; then
            token="$current_token"
        fi
    else
        read -p "API Token: " -r token
    fi

    if [[ -z "$token" ]]; then
        log_warn "No API token provided"
        return 1
    fi

    mkdir -p "$CLAUDE_CONFIG_DIR"

    # Initialize config file if not exists
    if [[ ! -f "$config_file" ]]; then
        echo '{}' > "$config_file"
    fi

    # Update config using jq if available
    if command -v jq &>/dev/null; then
        tmp=$(mktemp)
        jq --arg key "$token" --arg url "$default_url" ".${model_name} = {authToken: \$key, baseUrl: \$url}" "$config_file" > "$tmp"
        mv "$tmp" "$config_file"
    else
        log_error "jq is required for config.json editing. For GLM/Kimi use: $SCRIPT_NAME config"
        return 1
    fi

    log_success "Config saved for: ${color_bold}${model_name}${color_reset}"
    echo ""
    echo -e "Settings:"
    echo -e "  API Token: ${token:0:15}... (hidden)"
    echo -e "  Base URL: $default_url"
    echo ""
    echo -e "Now you can run:"
    if [[ "$model_name" == "claude" ]]; then
        echo -e "  ${color_blue}claude${color_reset}"
    else
        echo -e "  ${color_blue}claude-${model_name}${color_reset}"
    fi
}

cmd_setup() {
    echo ""
    echo -e "${color_bold}${color_blue}═══════════════════════════════════════════════════${color_reset}"
    echo -e "${color_bold}${color_blue}  Claude Code Model Switcher Setup${color_reset}"
    echo -e "${color_bold}${color_blue}═══════════════════════════════════════════════════${color_reset}"
    echo ""

    mkdir -p "$CLAUDE_CONFIG_DIR"

    while true; do
        local glm_file kimi_file glm_ok kimi_ok
        glm_file="$(_settings_file_for_provider glm)"
        kimi_file="$(_settings_file_for_provider kimi)"
        glm_ok="no"
        kimi_ok="no"
        [[ -n "$(_read_existing_token_from_settings "$glm_file" || true)" ]] && glm_ok="yes"
        [[ -n "$(_read_existing_token_from_settings "$kimi_file" || true)" ]] && kimi_ok="yes"

        echo -e "${color_bold}Configure API keys (repeatable)${color_reset}"
        echo ""
        echo -e "  ${color_green}1${color_reset}. GLM 4.7 & 5 (configured: ${glm_ok})"
        echo -e "       - Use /model to switch between glm-4.7 and glm-5"
        echo -e "  ${color_green}2${color_reset}. Kimi 2.5 (configured: ${kimi_ok})"
        echo -e "  ${color_green}3${color_reset}. Done"
        echo ""
        read -r -p "Select option (1-3): " choice

        case "$choice" in
            1) cmd_config glm || true ;;
            2) cmd_config kimi || true ;;
            3) break ;;
            *) log_warn "Invalid selection" ;;
        esac
        echo ""
    done

    echo -e "${color_bold}${color_green}═══════════════════════════════════════════════════${color_reset}"
    echo -e "${color_bold}${color_green}  Setup Complete!${color_reset}"
    echo -e "${color_bold}${color_green}═══════════════════════════════════════════════════${color_reset}"
    echo ""
    echo -e "You can now use:"
    echo -e "  ${color_blue}claude${color_reset}           # Claude (Sonnet 4.5)"
    echo -e "  ${color_blue}claude-glm${color_reset}       # GLM 4.7"
    echo -e "  ${color_blue}claude-kimi${color_reset}      # Kimi 2.5"
    echo ""
}

cmd_help() {
    cat << EOF
 ${color_bold}Claude Code Model Switcher${color_reset} v${VERSION}

 ${color_bold}USAGE${color_reset}
     $SCRIPT_NAME <command> [options]

 ${color_bold}COMMANDS${color_reset}
     ${color_green}setup${color_reset}              Setup all API keys at once
     ${color_green}current${color_reset}           Show current default model
     ${color_green}list${color_reset}              List all available model presets
     ${color_green}set${color_reset} <model>       Set default model (without running)
     ${color_green}use${color_reset} <alias|model> Run Claude Code with specified model
     ${color_green}config${color_reset} [model]    Configure API settings (interactive menu)
     ${color_green}help${color_reset}              Show this help message

 ${color_bold}MODEL ALIASES${color_reset}
EOF
    list_models

    cat << EOF
 ${color_bold}EXAMPLES${color_reset}
     $SCRIPT_NAME current              # Show current model
     $SCRIPT_NAME list                 # List all presets
     $SCRIPT_NAME use claude           # Run with default (Sonnet)
     $SCRIPT_NAME use claude-glm       # Run with GLM 4.7
     $SCRIPT_NAME use claude-sonnet    # Run with Sonnet
     $SCRIPT_NAME use glm-4.7          # Run with custom model

 ${color_bold}CONFIGURATION${color_reset}
     $SCRIPT_NAME config              # Interactive menu to select model
     $SCRIPT_NAME config glm          # Configure GLM API
     $SCRIPT_NAME config kimi         # Configure Kimi API

 ${color_bold}QUICK ALIASES${color_reset}
     You can also use direct commands:
     ${color_blue}claude${color_reset}              # Claude Sonnet 4.5
     ${color_blue}claude-opus${color_reset}         # Claude Opus 4.5
     ${color_blue}claude-sonnet${color_reset}       # Claude Sonnet 4.5
     ${color_blue}claude-haiku${color_reset}        # Claude Haiku 4.5
     ${color_blue}claude-glm${color_reset}          # GLM 4.7
     ${color_blue}claude-kimi${color_reset}         # Kimi 2.5

 ${color_bold}SUPPORTED MODELS${color_reset}
     ${color_green}Claude${color_reset}         Anthropic official (Sonnet, Opus, Haiku)
     ${color_green}GLM${color_reset}            Z.AI (glm-4.7, glm-5)
     ${color_green}Kimi${color_reset}           Moonshot AI (kimi-k2.5)

 ${color_bold}NOTES${color_reset}
     GLM supports both glm-4.7 and glm-5 models.
     Use '/model glm-4.7' or '/model glm-5' in Claude Code to switch.

EOF
}

# ============================================
# Main Entry Point
# ============================================

main() {
    local command="${1:-}"
    shift || true

    case "$command" in
        setup)
            cmd_setup
            ;;
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
        config)
            cmd_config "$@"
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
