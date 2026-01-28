#!/usr/bin/env bash
# Claude Code Model Switcher Uninstaller

set -euo pipefail

# ============================================
# Configuration
# ============================================

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
COMPLETION_DIR="$HOME/.claude-code-model-switcher"
SCRIPTS=("claude-model" "claude" "claude-glm" "claude-opus" "claude-sonnet" "claude-haiku")

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
# Uninstallation Functions
# ============================================

remove_scripts() {
    log_info "Removing installed scripts..."

    for script in "${SCRIPTS[@]}"; do
        local path="$INSTALL_DIR/$script"
        if [[ -f "$path" ]]; then
            rm "$path"
            log_success "Removed: $script"
        else
            log_warn "Not found: $script"
        fi
    done
}

remove_completions() {
    log_info "Removing shell completions..."

    if [[ -d "$COMPLETION_DIR" ]]; then
        rm -rf "$COMPLETION_DIR"
        log_success "Removed completion directory: $COMPLETION_DIR"
    else
        log_warn "Completion directory not found: $COMPLETION_DIR"
    fi

    # Remove completion sourcing from shell configs
    local configs=("$HOME/.bashrc" "$HOME/.zshrc")

    for config in "${configs[@]}"; do
        if [[ -f "$config" ]]; then
            # Remove claude-model completion lines
            if grep -q "claude-model" "$config"; then
                log_info "Removing completion references from $config"

                # Create backup
                cp "$config" "$config.bak"

                # Remove lines containing claude-model
                sed -i '/# Claude Code Model Switcher completion/d' "$config"
                sed -i '/claude-model\.bash/d' "$config"
                sed -i "/'$COMPLETION_DIR'/d" "$config"

                log_success "Updated: $config (backup saved as $config.bak)"
            fi
        fi
    done
}

remove_path_exports() {
    log_warn "PATH exports in shell configs were NOT removed."
    log_info "If you want to remove them manually, check your ~/.bashrc and ~/.zshrc for:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
}

show_post_uninstall() {
    echo ""
    echo -e "${color_bold}${color_green}═══════════════════════════════════════════════════${color_reset}"
    echo -e "${color_bold}${color_green}  Uninstallation Complete!${color_reset}"
    echo -e "${color_bold}${color_green}═══════════════════════════════════════════════════${color_reset}"
    echo ""
    echo -e "${color_yellow}⚠ Note:${color_reset} Restart your shell to apply all changes."
    echo ""
}

# ============================================
# Confirmation
# ============================================

confirm_uninstall() {
    echo ""
    echo -e "${color_bold}${color_red}This will uninstall Claude Code Model Switcher.${color_reset}"
    echo ""
    echo -e "The following will be removed:"
    echo -e "  ${color_blue}•${color_reset} Scripts in $INSTALL_DIR"
    echo -e "  ${color_blue}•${color_reset} Completions in $COMPLETION_DIR"
    echo -e "  ${color_blue}•${color_reset} Completion references from shell configs"
    echo ""
    read -p "Continue? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
}

# ============================================
# Main Uninstallation
# ============================================

main() {
    echo ""
    echo -e "${color_bold}${color_blue}Claude Code Model Switcher Uninstaller${color_reset}"

    confirm_uninstall

    remove_scripts
    remove_completions
    remove_path_exports
    show_post_uninstall
}

main "$@"
