#!/usr/bin/env bash
# Claude Code Model Switcher Uninstaller

set -euo pipefail

# ============================================
# Configuration
# ============================================

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
COMPLETION_DIR="$HOME/.claude-code-model-switcher"
CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CLAUDE_SETTINGS_FILE="$CLAUDE_CONFIG_DIR/settings.json"
SCRIPTS=("claude-model" "claude" "claude-glm" "claude-kimi" "cluade-glm" "cluade-kimi" "claude-deepseek" "claude-qwen" "claude-minimax" "claude-openrouter" "claude-opus" "claude-sonnet" "claude-haiku")

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

restore_original_claude() {
    log_info "Restoring original Claude binary..."

    local claude_locations=(
        "/usr/local/bin/claude.original"
        "/usr/bin/claude.original"
        "$HOME/.local/bin/claude.original"
        "$HOME/.npm-global/bin/claude.original"
        "$HOME/.npm/bin/claude.original"
    )

    for backup in "${claude_locations[@]}"; do
        if [[ -f "$backup" ]]; then
            local original="${backup%.original}"
            log_info "Restoring: $backup -> $original"
            cp "$backup" "$original"
            chmod +x "$original"
            log_success "Restored original claude: $original"

            # Remove backup
            rm "$backup"
            log_success "Removed backup: $backup"
            return 0
        fi
    done

    log_warn "No original claude backup found"
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

                # Remove lines containing claude-model (macOS and Linux compatible)
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i.bak '/# Claude Code Model Switcher completion/d' "$config"
                    sed -i.bak '/claude-model\.bash/d' "$config"
                    sed -i.bak "/'$COMPLETION_DIR'/d" "$config"
                    # Remove the backup file if created
                    rm -f "${config}.bak" 2>/dev/null || true
                else
                    sed -i '/# Claude Code Model Switcher completion/d' "$config"
                    sed -i '/claude-model\.bash/d' "$config"
                    sed -i "/'$COMPLETION_DIR'/d" "$config"
                fi

                log_success "Updated: $config (backup saved as $config.bak)"
            fi
        fi
    done
}

restore_claude_settings() {
    log_info "Restoring Claude Code settings to default..."

    if [[ ! -f "$CLAUDE_SETTINGS_FILE" ]]; then
        log_warn "Claude settings file not found: $CLAUDE_SETTINGS_FILE"
        return
    fi

    # Create backup
    cp "$CLAUDE_SETTINGS_FILE" "$CLAUDE_SETTINGS_FILE.bak"
    log_success "Backup created: $CLAUDE_SETTINGS_FILE.bak"

    if command -v jq &>/dev/null; then
        # Remove defaultModel using jq
        tmp_file=$(mktemp)
        jq 'del(.defaultModel)' "$CLAUDE_SETTINGS_FILE" > "$tmp_file"
        mv "$tmp_file" "$CLAUDE_SETTINGS_FILE"
        log_success "Removed defaultModel from settings.json"
    else
        # Fallback: remove defaultModel line using sed
        sed -i.bak '/"defaultModel"[[:space:]]*:[[:space:]]*"[^"]*"/d' "$CLAUDE_SETTINGS_FILE"
        # Clean up trailing comma
        sed -i 's/,([[:space:]]*)$/\1/' "$CLAUDE_SETTINGS_FILE"
        log_success "Removed defaultModel from settings.json"
    fi
}

remove_path_exports() {
    log_info "Removing aliases from shell configs..."

    local configs=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish")
    local found=false

    for config in "${configs[@]}"; do
            if [[ -f "$config" ]] && grep -q "Claude Code Model Switcher" "$config"; then
                log_info "Removing aliases from $config"
                # Create backup
                cp "$config" "$config.bak"
                # Remove the block (macOS and Linux compatible)
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i.bak '/# Claude Code Model Switcher/,+9d' "$config"
                    # Remove the backup file if created
                    rm -f "${config}.bak" 2>/dev/null || true
                else
                    sed -i '/# Claude Code Model Switcher/,+9d' "$config"
                fi
                log_success "Removed aliases from $config (backup: $config.bak)"
                found=true
            fi
    done

    if [[ "$found" == false ]]; then
        log_warn "No aliases found in shell configs"
    fi
}

show_post_uninstall() {
    echo ""
    echo -e "${color_bold}${color_green}═══════════════════════════════════════════════════${color_reset}"
    echo -e "${color_bold}${color_green}  Uninstallation Complete!${color_reset}"
    echo -e "${color_bold}${color_green}═══════════════════════════════════════════════════${color_reset}"
    echo ""
    echo -e "${color_bold}What was restored:${color_reset}"
    echo -e "  ${color_green}✓${color_reset} Original Claude Code binary restored"
    echo -e "  ${color_green}✓${color_reset} Claude Code defaultModel setting removed (back to default)"
    echo -e "  ${color_green}✓${color_reset} All wrapper scripts removed"
    echo -e "  ${color_green}✓${color_reset} Shell completions removed"
    echo -e "  ${color_green}✓${color_reset} Shell aliases cleaned up"
    echo ""
    echo -e "${color_yellow}⚠ Note:${color_reset} Restart your shell or run 'source ~/.bashrc' (or ~/.zshrc) to apply all changes."
    echo ""
    echo -e "${color_bold}Backups created:${color_reset}"
    echo -e "  ${color_blue}~${color_reset} Claude settings: $CLAUDE_SETTINGS_FILE.bak"
    echo -e "  ${color_blue}~${color_reset} Shell configs: *.bak files"
    echo ""
}

# ============================================
# Confirmation
# ============================================

confirm_uninstall() {
    echo ""
    echo -e "${color_bold}${color_red}This will uninstall Claude Code Model Switcher.${color_reset}"
    echo ""
    echo -e "The following will be removed or restored:"
    echo -e "  ${color_blue}•${color_reset} Original Claude Code binary will be restored from backup"
    echo -e "  ${color_blue}•${color_reset} Wrapper scripts in $INSTALL_DIR will be removed"
    echo -e "  ${color_blue}•${color_reset} Completions in $COMPLETION_DIR will be removed"
    echo -e "  ${color_blue}•${color_reset} Completion references from shell configs will be removed"
    echo -e "  ${color_blue}•${color_reset} PATH exports from shell configs will be removed"
    echo -e "  ${color_blue}•${color_reset} defaultModel from Claude settings will be removed (restored to default)"
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
    restore_original_claude
    remove_completions
    remove_path_exports
    restore_claude_settings
    show_post_uninstall
}

main "$@"
