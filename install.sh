#!/usr/bin/env bash
# Claude Code Model Switcher Installer

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN_DIR="${LOCAL_BIN_DIR:-$HOME/.local/bin}"
SOURCE_SCRIPT="$SCRIPT_DIR/claude-code-model-switcher.sh"
WRAPPERS_DIR="$SCRIPT_DIR/wrappers"

CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

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
# Installation Functions
# ============================================

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if Claude Code is installed
    if ! command -v claude &>/dev/null && [[ ! -f "/usr/local/bin/claude" ]] && [[ ! -f "$HOME/.local/bin/claude" ]]; then
        log_error "Claude Code not found"
        echo ""
        echo "Install Claude Code with:"
        echo "  npm install -g @anthropic-ai/claude-code"
        echo ""
        exit 1
    fi

    log_success "Claude Code found"
}

create_install_dir() {
    if [[ ! -d "$CLAUDE_CONFIG_DIR" ]]; then
        log_info "Creating Claude config directory: $CLAUDE_CONFIG_DIR"
        mkdir -p "$CLAUDE_CONFIG_DIR"
    fi

    if [[ ! -d "$LOCAL_BIN_DIR" ]]; then
        log_info "Creating local bin directory: $LOCAL_BIN_DIR"
        mkdir -p "$LOCAL_BIN_DIR"
    fi

    # Detect shell config file (only used for PATH hints)
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        SHELL_RC="$HOME/.zshrc"
        SHELL_NAME="zsh"
    elif [[ -n "${FISH_VERSION:-}" ]]; then
        SHELL_RC="$HOME/.config/fish/config.fish"
        SHELL_NAME="fish"
    else
        # Default to bash
        SHELL_RC="$HOME/.bashrc"
        SHELL_NAME="bash"
    fi
}

install_main_script() {
    log_info "Installing main script..."

    if [[ -f "$SOURCE_SCRIPT" ]]; then
        cp "$SOURCE_SCRIPT" "$LOCAL_BIN_DIR/claude-model"
        chmod +x "$LOCAL_BIN_DIR/claude-model"
        log_success "Installed 'claude-model' to: $LOCAL_BIN_DIR/claude-model"
    else
        log_warn "Main script not found at: $SOURCE_SCRIPT"
    fi
}

install_legacy_shims() {
    log_info "Installing legacy shims into $CLAUDE_CONFIG_DIR..."

    mkdir -p "$CLAUDE_CONFIG_DIR"

    # These files exist to support older aliases like:
    #   alias claude-glm='~/.claude/claude-glm.sh'
    # so existing shells keep working without requiring manual cleanup.
    local shim
    for shim in "claude.sh:claude" "claude-glm.sh:claude-glm" "claude-kimi.sh:claude-kimi"; do
        local shim_name="${shim%%:*}"
        local cmd_name="${shim##*:}"
        local shim_path="$CLAUDE_CONFIG_DIR/$shim_name"

        cat > "$shim_path" << EOF
#!/usr/bin/env bash
set -euo pipefail

if command -v "$cmd_name" >/dev/null 2>&1; then
  exec "$cmd_name" "\$@"
fi

if [[ -x "$LOCAL_BIN_DIR/$cmd_name" ]]; then
  exec "$LOCAL_BIN_DIR/$cmd_name" "\$@"
fi

echo "✗ Command not found: $cmd_name" >&2
echo "  Ensure $LOCAL_BIN_DIR is on your PATH." >&2
exit 1
EOF
        chmod +x "$shim_path"
        log_success "Installed: $shim_path"
    done
}

remove_old_aliases() {
    log_info "Cleaning old shell aliases (if any)..."

    # Remove the old alias block and any direct aliases that point to ~/.claude/*.sh
    # User may still need to restart shell for current session.
    local configs=("$HOME/.bashrc" "$HOME/.zshrc")
    local cfg

    for cfg in "${configs[@]}"; do
        [[ -f "$cfg" ]] || continue

        cp "$cfg" "$cfg.bak" 2>/dev/null || true

        # Remove any previous block header and known aliases (linux-compatible sed)
        sed -i '/# Claude Code Model Switcher/d' "$cfg" 2>/dev/null || true
        sed -i '/alias claude=/d' "$cfg" 2>/dev/null || true
        sed -i '/alias claude-glm=/d' "$cfg" 2>/dev/null || true
        sed -i '/alias claude-kimi=/d' "$cfg" 2>/dev/null || true
    done
}

install_wrapper_scripts() {
    log_info "Installing wrapper commands..."

    if [[ ! -d "$WRAPPERS_DIR" ]]; then
        log_error "Wrappers directory not found: $WRAPPERS_DIR"
        exit 1
    fi

    local wrappers=("claude" "claude-glm" "claude-kimi")

    for wrapper in "${wrappers[@]}"; do
        if [[ ! -f "$WRAPPERS_DIR/$wrapper" ]]; then
            log_error "Missing wrapper template: $WRAPPERS_DIR/$wrapper"
            exit 1
        fi

        # Backup an existing `claude` in ~/.local/bin only (optional)
        if [[ "$wrapper" == "claude" && -f "$LOCAL_BIN_DIR/claude" ]]; then
            if ! grep -q "Claude Code Model Switcher wrapper" "$LOCAL_BIN_DIR/claude" 2>/dev/null; then
                if [[ ! -f "$LOCAL_BIN_DIR/claude.original" ]]; then
                    cp "$LOCAL_BIN_DIR/claude" "$LOCAL_BIN_DIR/claude.original"
                    chmod +x "$LOCAL_BIN_DIR/claude.original" || true
                    log_warn "Backed up existing $LOCAL_BIN_DIR/claude to $LOCAL_BIN_DIR/claude.original"
                fi
            fi
        fi

        # Avoid `cp -> Text file busy` when overwriting an in-use executable:
        # write a temp file then atomically rename over the destination.
        local tmp
        tmp="$(mktemp "$LOCAL_BIN_DIR/.${wrapper}.tmp.XXXXXX")"
        cp "$WRAPPERS_DIR/$wrapper" "$tmp"
        chmod +x "$tmp"
        mv -f "$tmp" "$LOCAL_BIN_DIR/$wrapper"
        log_success "Installed: $LOCAL_BIN_DIR/$wrapper"
    done
}

write_provider_settings() {
    local name="$1"
    local base_url="$2"
    local model="$3"
    local token="$4"
    local auth_key_name="${5:-ANTHROPIC_AUTH_TOKEN}"
    local settings_file="$CLAUDE_CONFIG_DIR/${name}_settings.json"

    # For GLM, set up both glm-4.7 and glm-5 with appropriate defaults
    local sonnet_model="$model"
    local opus_model="$model"
    local available_models="$model"
    if [[ "$name" == "zai" ]]; then
        sonnet_model="glm-4.7"
        opus_model="glm-5"
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
    "ANTHROPIC_SMALL_FAST_MODEL": "$sonnet_model",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "$sonnet_model",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "$opus_model",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "$sonnet_model",
    "CLAUDE_CODE_SUBAGENT_MODEL": "$sonnet_model",
    "CLAUDE_CODE_AVAILABLE_MODELS": "$available_models"
  }
}
EOF
    )

    chmod 600 "$settings_file" 2>/dev/null || true
    log_success "Wrote settings: $settings_file"
}

_read_existing_token() {
    local settings_file="$1"
    [[ -f "$settings_file" ]] || return 0

    if command -v jq >/dev/null 2>&1; then
        jq -r '.env.ANTHROPIC_API_KEY // .env.ANTHROPIC_AUTH_TOKEN // empty' "$settings_file" 2>/dev/null || true
    else
        grep -o '"ANTHROPIC_API_KEY"[[:space:]]*:[[:space:]]*"[^"]*"' "$settings_file" 2>/dev/null | head -1 | sed 's/.*"ANTHROPIC_API_KEY"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true
    fi
}

configure_api_keys() {
    local zai_file="$CLAUDE_CONFIG_DIR/zai_settings.json"
    local kimi_file="$CLAUDE_CONFIG_DIR/kimi_settings.json"
    local existing_zai existing_kimi
    existing_zai="$(_read_existing_token "$zai_file" || true)"
    existing_kimi="$(_read_existing_token "$kimi_file" || true)"

    echo ""
    echo -e "${color_bold}${color_blue}Configure API Keys${color_reset}"
    echo ""

    local zai_status="not configured"
    local kimi_status="not configured"
    [[ -n "${existing_zai:-}" ]] && zai_status="${existing_zai:0:12}... (configured)"
    [[ -n "${existing_kimi:-}" ]] && kimi_status="${existing_kimi:0:12}... (configured)"

    echo "  1) GLM 4.7 & 5 (Z.ai) - $zai_status"
    echo "  2) Kimi 2.5 (Moonshot) - $kimi_status"
    echo ""
    echo -e "${color_yellow}Enter choices to update (e.g. 1 2), or press Enter to keep existing:${color_reset}"
    read -r -p "> " choices

    if [[ -z "${choices// }" ]]; then
        log_info "Keeping existing API key configuration"
        return 0
    fi

    local choice
    for choice in $choices; do
        case "$choice" in
            1)
                echo ""
                if [[ -n "${existing_zai:-}" ]]; then
                    echo "Current GLM key: ${existing_zai:0:12}..."
                    echo "Press Enter to keep, or type new key:"
                fi
                read -r -s -p "GLM API key: " glm_key
                echo ""
                if [[ -n "${glm_key:-}" ]]; then
                    write_provider_settings "zai" "https://api.z.ai/api/anthropic" "glm-5" "$glm_key" "ANTHROPIC_AUTH_TOKEN"
                elif [[ -n "${existing_zai:-}" ]]; then
                    log_info "Kept existing GLM API key"
                else
                    log_warn "Skipped GLM (empty key)"
                fi
                ;;
            2)
                echo ""
                if [[ -n "${existing_kimi:-}" ]]; then
                    echo "Current Kimi key: ${existing_kimi:0:12}..."
                    echo "Press Enter to keep, or type new key:"
                fi
                read -r -s -p "Kimi API key: " kimi_key
                echo ""
                if [[ -n "${kimi_key:-}" ]]; then
                    write_provider_settings "kimi" "https://api.kimi.com/coding/" "kimi-k2.5" "$kimi_key" "ANTHROPIC_API_KEY"
                elif [[ -n "${existing_kimi:-}" ]]; then
                    log_info "Kept existing Kimi API key"
                else
                    log_warn "Skipped Kimi (empty key)"
                fi
                ;;
            *)
                log_warn "Unknown choice: $choice (skipped)"
                ;;
        esac
    done
}

configure_dangerous_mode() {
    local config_file="$CLAUDE_CONFIG_DIR/.model-switcher-config"

    echo ""
    echo -e "${color_bold}${color_blue}Safety Mode Configuration${color_reset}"
    echo ""
    echo -e "${color_yellow}--dangerously-skip-permissions${color_reset} bypasses Claude's safety prompts."
    echo "This allows Claude to execute commands without asking for confirmation."
    echo ""
    echo "  1) Enable by default (no confirmation prompts)"
    echo "  2) Disable by default (use --dangerously-skip-permissions flag manually)"
    echo ""
    read -p "Choose [1/2] (default: 2): " -r danger_choice

    local auto_danger="false"
    case "${danger_choice:-2}" in
        1)
            auto_danger="true"
            log_success "Auto --dangerously-skip-permissions: ENABLED"
            ;;
        *)
            auto_danger="false"
            log_success "Auto --dangerously-skip-permissions: DISABLED"
            log_info "Use: claude-glm --dangerously-skip-permissions to enable per-session"
            ;;
    esac

    # Write config file
    (umask 077
        cat > "$config_file" << EOF
# Claude Code Model Switcher Configuration
AUTO_DANGEROUS_MODE=$auto_danger
EOF
    )
    chmod 600 "$config_file" 2>/dev/null || true
}

ensure_path_hint() {
    if [[ ":$PATH:" == *":$LOCAL_BIN_DIR:"* ]]; then
        return 0
    fi

    log_warn "$LOCAL_BIN_DIR is not in your PATH"
    if [[ -n "${SHELL_RC:-}" ]]; then
        log_info "To enable the commands in new shells, add this to $SHELL_RC:"
        echo "  export PATH=\"$LOCAL_BIN_DIR:\$PATH\""
    fi
}

show_post_install() {
    echo ""
    echo -e "${color_bold}${color_green}═════════════════════════════════════════════════${color_reset}"
    echo -e "${color_bold}${color_green}  Installation Complete!${color_reset}"
    echo -e "${color_bold}${color_green}═════════════════════════════════════════════════${color_reset}"
    echo ""
    echo -e "${color_yellow}⚠ Next Step:${color_reset}"
    echo "  If the commands aren't found, ensure $LOCAL_BIN_DIR is on your PATH."
    echo ""
    echo -e "${color_bold}Available Commands:${color_reset}"
    echo -e "  ${color_blue}claude${color_reset}           # Claude (default) + --dangerously-skip-permissions"
    echo -e "  ${color_blue}claude-glm${color_reset}       # GLM 4.7 & 5 (use /model to switch)"
    echo -e "  ${color_blue}claude-kimi${color_reset}      # Kimi 2.5"
    echo ""
}

# ============================================
# Main Installation
# ============================================

main() {
    echo ""
    echo -e "${color_bold}${color_blue}Claude Code Model Switcher Installer${color_reset}"
    echo ""

    check_prerequisites
    create_install_dir
    install_main_script
    install_legacy_shims
    remove_old_aliases
    install_wrapper_scripts
    configure_api_keys
    configure_dangerous_mode
    ensure_path_hint
    show_post_install
}

main "$@"
