#!/usr/bin/env bash
# Claude Code Model Switcher Installer

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
LOCAL_BIN_DIR="${LOCAL_BIN_DIR:-$HOME/.local/bin}"
SOURCE_SCRIPT="$SCRIPT_DIR/claude-code-model-switcher.sh"

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
    if [[ ! -d "$INSTALL_DIR" ]]; then
        log_info "Creating install directory: $INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
    fi

    # Detect shell config file
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

    # Copy to install directory
    if [[ -f "$SOURCE_SCRIPT" ]]; then
        cp "$SOURCE_SCRIPT" "$INSTALL_DIR/claude-model"
        chmod +x "$INSTALL_DIR/claude-model"
        log_success "Installed 'claude-model' to: $INSTALL_DIR/claude-model"

        # Also copy to ~/.local/bin for PATH access
        if [[ -d "$LOCAL_BIN_DIR" ]] || mkdir -p "$LOCAL_BIN_DIR" 2>/dev/null; then
            cp "$SOURCE_SCRIPT" "$LOCAL_BIN_DIR/claude-model"
            chmod +x "$LOCAL_BIN_DIR/claude-model"
            log_success "Installed 'claude-model' to: $LOCAL_BIN_DIR/claude-model"
        fi
    else
        log_warn "Main script not found at: $SOURCE_SCRIPT"
    fi
}

install_wrapper_scripts() {
    log_info "Installing wrapper scripts..."

    # Copy wrapper scripts to ~/.claude/
    local wrappers=("claude.sh" "claude-glm.sh" "claude-kimi.sh" "claude-deepseek.sh" "claude-qwen.sh" "claude-minimax.sh" "claude-openrouter.sh")

    for wrapper in "${wrappers[@]}"; do
        if [[ -f "$SCRIPT_DIR/.claude/$wrapper" ]]; then
            cp "$SCRIPT_DIR/.claude/$wrapper" "$INSTALL_DIR/"
            chmod +x "$INSTALL_DIR/$wrapper"
            log_success "Installed: $wrapper"
        else
            log_warn "Wrapper not found: $wrapper"
        fi
    done
}

add_shell_aliases() {
    log_info "Adding aliases..."

    # Add to .bashrc
    local bashrc="$HOME/.bashrc"
    if [[ -f "$bashrc" ]]; then
        sed -i.bak '/# Claude Code Model Switcher/d' "$bashrc" 2>/dev/null || true
        sed -i.bak '/alias claude=/d' "$bashrc" 2>/dev/null || true
        sed -i.bak '/alias claude-glm=/d' "$bashrc" 2>/dev/null || true
        sed -i.bak '/alias claude-kimi=/d' "$bashrc" 2>/dev/null || true
        sed -i.bak '/alias claude-deepseek=/d' "$bashrc" 2>/dev/null || true
        sed -i.bak '/alias claude-qwen=/d' "$bashrc" 2>/dev/null || true
        sed -i.bak '/alias claude-minimax=/d' "$bashrc" 2>/dev/null || true
        sed -i.bak '/alias claude-openrouter=/d' "$bashrc" 2>/dev/null || true

        cat >> "$bashrc" << 'EOF'

# Claude Code Model Switcher
alias claude='~/.claude/claude.sh'              # Claude (Sonnet 4.5)
alias claude-glm='~/.claude/claude-glm.sh'      # GLM 4.7
alias claude-kimi='~/.claude/claude-kimi.sh'    # Kimi K2
alias claude-deepseek='~/.claude/claude-deepseek.sh'    # DeepSeek
alias claude-qwen='~/.claude/claude-qwen.sh'            # Qwen Plus
alias claude-minimax='~/.claude/claude-minimax.sh'     # MiniMax M2
alias claude-openrouter='~/.claude/claude-openrouter.sh' # OpenRouter
EOF
        log_success "Aliases added to: $bashrc"
    fi

    # Add to .zshrc
    local zshrc="$HOME/.zshrc"
    if [[ -f "$zshrc" ]]; then
        sed -i.bak '/# Claude Code Model Switcher/d' "$zshrc" 2>/dev/null || true
        sed -i.bak '/alias claude=/d' "$zshrc" 2>/dev/null || true
        sed -i.bak '/alias claude-glm=/d' "$zshrc" 2>/dev/null || true
        sed -i.bak '/alias claude-kimi=/d' "$zshrc" 2>/dev/null || true
        sed -i.bak '/alias claude-deepseek=/d' "$zshrc" 2>/dev/null || true
        sed -i.bak '/alias claude-qwen=/d' "$zshrc" 2>/dev/null || true
        sed -i.bak '/alias claude-minimax=/d' "$zshrc" 2>/dev/null || true
        sed -i.bak '/alias claude-openrouter=/d' "$zshrc" 2>/dev/null || true

        cat >> "$zshrc" << 'EOF'

# Claude Code Model Switcher
alias claude='~/.claude/claude.sh'              # Claude (Sonnet 4.5)
alias claude-glm='~/.claude/claude-glm.sh'      # GLM 4.7
alias claude-kimi='~/.claude/claude-kimi.sh'    # Kimi K2
alias claude-deepseek='~/.claude/claude-deepseek.sh'    # DeepSeek
alias claude-qwen='~/.claude/claude-qwen.sh'            # Qwen Plus
alias claude-minimax='~/.claude/claude-minimax.sh'     # MiniMax M2
alias claude-openrouter='~/.claude/claude-openrouter.sh' # OpenRouter
EOF
        log_success "Aliases added to: $zshrc"
    fi
}

show_post_install() {
    echo ""
    echo -e "${color_bold}${color_green}═════════════════════════════════════════════════${color_reset}"
    echo -e "${color_bold}${color_green}  Installation Complete!${color_reset}"
    echo -e "${color_bold}${color_green}═════════════════════════════════════════════════${color_reset}"
    echo ""
    echo -e "${color_yellow}⚠ Next Step:${color_reset}"
    echo "  1. Reload your shell:"
    echo -e "     ${color_blue}source $SHELL_RC${color_reset}"
    echo ""
    echo "  2. Setup API keys:"
    echo -e "     ${color_blue}claude-model setup${color_reset}"
    echo "     or"
    echo -e "     ${color_blue}claude-model config${color_reset}  # Interactive menu"
    echo ""
    echo -e "${color_bold}Available Commands:${color_reset}"
    echo -e "  ${color_blue}claude${color_reset}           # Claude (Sonnet 4.5)"
    echo -e "  ${color_blue}claude-glm${color_reset}       # GLM 4.7"
    echo -e "  ${color_blue}claude-kimi${color_reset}      # Kimi K2"
    echo -e "  ${color_blue}claude-deepseek${color_reset}  # DeepSeek"
    echo -e "  ${color_blue}claude-qwen${color_reset}      # Qwen Plus"
    echo -e "  ${color_blue}claude-minimax${color_reset}   # MiniMax M2"
    echo -e "  ${color_blue}claude-openrouter${color_reset} # OpenRouter"
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
    install_wrapper_scripts
    add_shell_aliases
    show_post_install
}

main "$@"
