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
        claude)           echo "claude-sonnet-4-5-20250515" ;;
        claude-opus)      echo "claude-opus-4-5-20251101" ;;
        claude-sonnet)    echo "claude-sonnet-4-5-20250515" ;;
        claude-haiku)     echo "claude-haiku-4-5-20250114" ;;
        claude-glm)       echo "glm-4.7" ;;
        claude-kimi)      echo "kimi-k2-thinking" ;;
        claude-deepseek)  echo "deepseek-chat" ;;
        claude-qwen)      echo "qwen-plus" ;;
        claude-minimax)   echo "MiniMax-M2" ;;
        claude-openrouter)echo "anthropic/claude-sonnet-4-5-20250515" ;;
        *)                echo "" ;;
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
    for alias in claude claude-opus claude-sonnet claude-haiku claude-glm claude-kimi claude-deepseek claude-qwen claude-minimax claude-openrouter; do
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

cmd_config() {
    local model_name="${1:-}"

    # If no model specified, show interactive menu
    if [[ -z "${model_name:-}" ]]; then
        echo -e "\n${color_bold}${color_blue}═══════════════════════════════════════════════════${color_reset}"
        echo -e "${color_bold}${color_blue}  Select Model to Configure${color_reset}"
        echo -e "${color_bold}${color_blue}═══════════════════════════════════════════════════${color_reset}"
        echo ""
        echo -e "  ${color_green}1${color_reset}. claude        (Anthropic Claude)"
        echo -e "  ${color_green}2${color_reset}. glm           (Zhipu GLM)"
        echo -e "  ${color_green}3${color_reset}. kimi          (Moonshot AI Kimi)"
        echo -e "  ${color_green}4${color_reset}. deepseek      (DeepSeek)"
        echo -e "  ${color_green}5${color_reset}. qwen          (Alibaba Qwen)"
        echo -e "  ${color_green}6${color_reset}. minimax       (MiniMax)"
        echo -e "  ${color_green}7${color_reset}. openrouter    (OpenRouter)"
        echo ""
        read -p "Select option (1-7): " -r choice

        case "$choice" in
            1) model_name="claude" ;;
            2) model_name="glm" ;;
            3) model_name="kimi" ;;
            4) model_name="deepseek" ;;
            5) model_name="qwen" ;;
            6) model_name="minimax" ;;
            7) model_name="openrouter" ;;
            *)
                log_error "Invalid selection"
                return 1
                ;;
        esac
    fi

    local config_file="$CLAUDE_CONFIG_DIR/config.json"

    # Get default base URL
    local default_url=""
    case "$model_name" in
        claude)      default_url="https://api.anthropic.com" ;;
        glm)         default_url="https://api.z.ai/api/coding/paas/v4" ;;
        kimi)        default_url="https://api.moonshot.ai/v1" ;;
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
        log_error "jq is required. Install with: brew install jq"
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

    local config_file="$CLAUDE_CONFIG_DIR/config.json"

    # Initialize config file if not exists
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
{
  "claude": {"authToken": "", "baseUrl": "https://api.anthropic.com"},
  "glm": {"authToken": "", "baseUrl": "https://api.z.ai/api/coding/paas/v4"},
  "kimi": {"authToken": "", "baseUrl": "https://api.moonshot.ai/v1"},
  "deepseek": {"authToken": "", "baseUrl": "https://api.deepseek.com/anthropic"},
  "qwen": {"authToken": "", "baseUrl": "https://dashscope-intl.aliyuncs.com/apps/anthropic"},
  "minimax": {"authToken": "", "baseUrl": "https://api.minimax.io/anthropic"},
  "openrouter": {"authToken": "", "baseUrl": "https://openrouter.ai/api"}
}
EOF
    fi

    # Check for jq
    if ! command -v jq &>/dev/null; then
        log_error "jq is required for setup. Install with: brew install jq (macOS) or sudo apt-get install jq (Ubuntu)"
        exit 1
    fi

    echo -e "${color_bold}Configure API Keys${color_reset}"
    echo ""
    echo -e "${color_yellow}Enter your API keys below. Press Enter to skip a model.${color_reset}"
    echo ""

    # Models to configure
    local models=("claude" "glm" "kimi" "deepseek" "qwen" "minimax" "openrouter")
    local model_names=("Claude (Anthropic)" "GLM (Zhipu)" "Kimi (Moonshot)" "DeepSeek" "Qwen (Alibaba)" "MiniMax" "OpenRouter")

    for i in "${!models[@]}"; do
        local model="${models[$i]}"
        local name="${model_names[$i]}"

        # Load existing key
        local existing_key
        existing_key=$(jq -r ".${model}.authToken // \"\"" "$config_file" 2>/dev/null)

        # Check for existing keys in other locations for claude
        if [[ "$model" == "claude" && -z "$existing_key" ]]; then
            if [[ -f "$HOME/.anthropic-api-key" ]]; then
                existing_key=$(cat "$HOME/.anthropic-api-key" 2>/dev/null)
            elif [[ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
                existing_key="$ANTHROPIC_AUTH_TOKEN"
            fi
        fi

        local key=""
        if [[ -n "$existing_key" && "$existing_key" != "sk-your-api-key" && "$existing_key" != "sk-test-"* ]]; then
            echo -e "${color_green}✓${color_reset} ${name} API key found: ${existing_key:0:15}..."
            echo "  Press Enter to use, or type a new key:"
            read -p "> " -r input
            if [[ -n "$input" ]]; then
                key="$input"
            else
                key="$existing_key"
            fi
        else
            echo -n "${color_blue}${name} API Key${color_reset}: "
            read -r key
        fi

        if [[ -n "$key" ]]; then
            tmp=$(mktemp)
            jq --arg k "$key" ".${model}.authToken = \$k" "$config_file" > "$tmp" && mv "$tmp" "$config_file"
            log_success "${name} configuration saved"
        fi
        echo ""
    done

    echo -e "${color_bold}${color_green}═══════════════════════════════════════════════════${color_reset}"
    echo -e "${color_bold}${color_green}  Setup Complete!${color_reset}"
    echo -e "${color_bold}${color_green}═══════════════════════════════════════════════════${color_reset}"
    echo ""
    echo -e "You can now use:"
    echo -e "  ${color_blue}claude${color_reset}           # Claude (Sonnet 4.5)"
    echo -e "  ${color_blue}claude-glm${color_reset}       # GLM 4.7"
    echo -e "  ${color_blue}claude-kimi${color_reset}      # Kimi K2"
    echo -e "  ${color_blue}claude-deepseek${color_reset}  # DeepSeek"
    echo -e "  ${color_blue}claude-qwen${color_reset}      # Qwen Plus"
    echo -e "  ${color_blue}claude-minimax${color_reset}   # MiniMax M2"
    echo -e "  ${color_blue}claude-openrouter${color_reset} # OpenRouter"
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
     $SCRIPT_NAME config deepseek     # Configure DeepSeek API

 ${color_bold}QUICK ALIASES${color_reset}
     You can also use direct commands:
     ${color_blue}claude${color_reset}              # Claude Sonnet 4.5
     ${color_blue}claude-opus${color_reset}         # Claude Opus 4.5
     ${color_blue}claude-sonnet${color_reset}       # Claude Sonnet 4.5
     ${color_blue}claude-haiku${color_reset}        # Claude Haiku 4.5
     ${color_blue}claude-glm${color_reset}          # GLM 4.7
     ${color_blue}claude-kimi${color_reset}         # Kimi K2
     ${color_blue}claude-deepseek${color_reset}     # DeepSeek
     ${color_blue}claude-qwen${color_reset}         # Qwen Plus
     ${color_blue}claude-minimax${color_reset}      # MiniMax M2
     ${color_blue}claude-openrouter${color_reset}   # OpenRouter

 ${color_bold}SUPPORTED MODELS${color_reset}
     ${color_green}Claude${color_reset}         Anthropic official (Sonnet, Opus, Haiku)
     ${color_green}GLM${color_reset}            Zhipu AI (glm-4.7, glm-4.5-air)
     ${color_green}Kimi${color_reset}           Moonshot AI (kimi-k2-thinking)
     ${color_green}DeepSeek${color_reset}       DeepSeek (deepseek-chat, deepseek-reasoner)
     ${color_green}Qwen${color_reset}           Alibaba (qwen-plus, qwen-max, qwen-coder)
     ${color_green}MiniMax${color_reset}        MiniMax (MiniMax-M2)
     ${color_green}OpenRouter${color_reset}     100+ models via openrouter.ai

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
