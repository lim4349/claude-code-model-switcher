# Claude Code Model Switcher - Windows Installer
# Run: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

# ============================================
# Configuration
# ============================================

$ScriptDir = $PSScriptRoot
$LocalBinDir = if ($env:LOCAL_BIN_DIR) { $env:LOCAL_BIN_DIR } else { Join-Path $env:USERPROFILE ".local\bin" }
$ClaudeConfigDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }
$SourceScript = Join-Path $ScriptDir "claude-code-model-switcher.sh"
$WrappersDir = Join-Path $ScriptDir "wrappers"

# ============================================
# Helpers
# ============================================

function Log-Info { Write-Host "i $args" -ForegroundColor Cyan }
function Log-Success { Write-Host "OK $args" -ForegroundColor Green }
function Log-Warn { Write-Host "WARN $args" -ForegroundColor Yellow }
function Log-Error { Write-Host "ERR $args" -ForegroundColor Red; throw "Install failed" }

# ============================================
# Installation
# ============================================

function Check-Prerequisites {
    Log-Info "Checking prerequisites..."
    $found = $false
    if (Get-Command claude -ErrorAction SilentlyContinue) { $found = $true }
    if (Test-Path (Join-Path $LocalBinDir "claude")) { $found = $true }
    $npmClaude = $null
    try {
        $npmRoot = npm prefix -g 2>$null
        if ($npmRoot -and (Test-Path (Join-Path $npmRoot "claude.cmd"))) { $found = $true }
    } catch {}
    if (-not $found) {
        Log-Error "Claude Code not found. Install with: npm install -g @anthropic-ai/claude-code"
    }
    Log-Success "Claude Code found"
}

function Create-InstallDir {
    if (-not (Test-Path $ClaudeConfigDir)) {
        Log-Info "Creating config directory: $ClaudeConfigDir"
        New-Item -ItemType Directory -Path $ClaudeConfigDir -Force | Out-Null
    }
    if (-not (Test-Path $LocalBinDir)) {
        Log-Info "Creating local bin directory: $LocalBinDir"
        New-Item -ItemType Directory -Path $LocalBinDir -Force | Out-Null
    }
}

function Install-MainScript {
    Log-Info "Installing main script..."
    if (Test-Path $SourceScript) {
        Copy-Item -Path $SourceScript -Destination (Join-Path $LocalBinDir "claude-model") -Force
        Log-Success "Installed claude-model to $LocalBinDir"
    } else {
        Log-Warn "Main script not found: $SourceScript"
    }
}

function Get-BashPath {
    # Prefer Git for Windows bash so Windows paths (C:\...) work. WSL /bin/bash cannot run C:\ paths.
    $gitBash = "C:\Program Files\Git\bin\bash.exe"
    if (Test-Path $gitBash) { return $gitBash }
    $gitBash = "C:\Program Files (x86)\Git\bin\bash.exe"
    if (Test-Path $gitBash) { return $gitBash }
    $bash = Get-Command bash -ErrorAction SilentlyContinue
    if ($bash) { return $bash.Source }
    return $null
}

function Install-WrapperScripts {
    Log-Info "Installing wrapper commands..."
    if (-not (Test-Path $WrappersDir)) { Log-Error "Wrappers directory not found: $WrappersDir" }

    $bashExe = Get-BashPath
    if (-not $bashExe) {
        Log-Warn "bash not found (install Git for Windows for full wrapper support)."
        Log-Info "Copying wrapper scripts to $LocalBinDir - run them with: bash .local/bin/claude"
    }

    $wrappers = @("claude", "claude-glm", "claude-kimi")
    foreach ($w in $wrappers) {
        $src = Join-Path $WrappersDir $w
        if (-not (Test-Path $src)) { Log-Error "Missing wrapper: $src" }
        $dest = Join-Path $LocalBinDir $w
        Copy-Item -Path $src -Destination $dest -Force
        Log-Success "Installed: $dest"
    }

    # Create .cmd launchers so "claude" works in PowerShell/CMD (via bash)
    if ($bashExe) {
        foreach ($w in $wrappers) {
            $cmdPath = Join-Path $LocalBinDir "$w.cmd"
            $wrapperPath = Join-Path $LocalBinDir $w
            $content = @"
@echo off
"$bashExe" "$wrapperPath" %*
"@
            $text = $content -replace "`r`n", "`n"
            Set-Content -Path $cmdPath -Value $text -Encoding ASCII -NoNewline
            Log-Success "Installed launcher: $cmdPath"
        }
    } else {
        Log-Warn "No .cmd launchers created (bash not found). Add $LocalBinDir to PATH and run: bash claude"
    }
}

function Install-LegacyShims {
    Log-Info "Installing legacy shims..."
    $shims = @(
        @{ Name = "claude.sh"; Cmd = "claude" }
        @{ Name = "claude-glm.sh"; Cmd = "claude-glm" }
        @{ Name = "claude-kimi.sh"; Cmd = "claude-kimi" }
    )
    $localBinEsc = $LocalBinDir -replace '\\', '/'
    foreach ($s in $shims) {
        $p = Join-Path $ClaudeConfigDir $s.Name
        $content = @"
#!/usr/bin/env bash
set -euo pipefail
if command -v $($s.Cmd) >/dev/null 2>&1; then exec $($s.Cmd) "`$@"; fi
if [[ -x "$localBinEsc/$($s.Cmd)" ]]; then exec "$localBinEsc/$($s.Cmd)" "`$@"; fi
echo "Command not found: $($s.Cmd)" >&2
exit 1
"@
        $text = $content -replace "`r`n", "`n"
        Set-Content -Path $p -Value $text -Encoding UTF8 -NoNewline
        Log-Success "Installed shim: $p"
    }
}

function Write-ProviderSettings {
    param([string]$Name, [string]$BaseUrl, [string]$Model, [string]$Token, [string]$AuthKey = "ANTHROPIC_AUTH_TOKEN")
    $settingsFile = Join-Path $ClaudeConfigDir "${Name}_settings.json"
    $sonnet = $Model; $opus = $Model; $available = $Model
    if ($Name -eq "zai") { $sonnet = "glm-4.7"; $opus = "glm-5"; $available = "glm-4.7,glm-5" }
    $json = @{
        env = @{
            ANTHROPIC_BASE_URL = $BaseUrl
            $AuthKey = $Token
            API_TIMEOUT_MS = "3000000"
            CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
            ANTHROPIC_MODEL = $Model
            ANTHROPIC_SMALL_FAST_MODEL = $sonnet
            ANTHROPIC_DEFAULT_SONNET_MODEL = $sonnet
            ANTHROPIC_DEFAULT_OPUS_MODEL = $opus
            ANTHROPIC_DEFAULT_HAIKU_MODEL = $sonnet
            CLAUDE_CODE_SUBAGENT_MODEL = $sonnet
            CLAUDE_CODE_AVAILABLE_MODELS = $available
        }
    } | ConvertTo-Json -Depth 5
    Set-Content -Path $settingsFile -Value $json -Encoding UTF8
    Log-Success "Wrote settings: $settingsFile"
}

function Get-ExistingToken {
    param([string]$SettingsFile)
    if (-not (Test-Path $SettingsFile)) { return "" }
    try {
        $j = Get-Content $SettingsFile -Raw | ConvertFrom-Json
        if ($j.env.ANTHROPIC_API_KEY) { return $j.env.ANTHROPIC_API_KEY }
        if ($j.env.ANTHROPIC_AUTH_TOKEN) { return $j.env.ANTHROPIC_AUTH_TOKEN }
        return ""
    } catch { return "" }
}

function Configure-ApiKeys {
    Write-Host ""
    Write-Host "Configure API Keys" -ForegroundColor Blue
    Write-Host ""

    $zaiFile = Join-Path $ClaudeConfigDir "zai_settings.json"
    $kimiFile = Join-Path $ClaudeConfigDir "kimi_settings.json"
    $existingZai = Get-ExistingToken $zaiFile
    $existingKimi = Get-ExistingToken $kimiFile

    $zaiStatus = "not configured"
    $kimiStatus = "not configured"
    if ($existingZai) { $zaiStatus = $existingZai.Substring(0, [Math]::Min(12, $existingZai.Length)) + "... (configured)" }
    if ($existingKimi) { $kimiStatus = $existingKimi.Substring(0, [Math]::Min(12, $existingKimi.Length)) + "... (configured)" }

    Write-Host "  1) GLM 4.7 & 5 (Z.ai) - $zaiStatus"
    Write-Host "  2) Kimi 2.5 (Moonshot) - $kimiStatus"
    Write-Host ""
    $choices = Read-Host "Enter choices to update (e.g. 1 2), or press Enter to keep existing"

    if ([string]::IsNullOrWhiteSpace($choices)) {
        Log-Info "Keeping existing API key configuration"
        return
    }

    foreach ($c in $choices.Trim().Split()) {
        switch ($c) {
            "1" {
                if ($existingZai) { Write-Host "Current GLM key: $($existingZai.Substring(0, [Math]::Min(12, $existingZai.Length)))... Press Enter to keep" }
                $glmKey = Read-Host "GLM API key"
                if ($glmKey) { Write-ProviderSettings "zai" "https://api.z.ai/api/anthropic" "glm-5" $glmKey "ANTHROPIC_AUTH_TOKEN" }
                elseif ($existingZai) { Log-Info "Kept existing GLM key" }
                else { Log-Warn "Skipped GLM (empty key)" }
            }
            "2" {
                if ($existingKimi) { Write-Host "Current Kimi key: $($existingKimi.Substring(0, [Math]::Min(12, $existingKimi.Length)))... Press Enter to keep" }
                $kimiKey = Read-Host "Kimi API key"
                if ($kimiKey) { Write-ProviderSettings "kimi" "https://api.kimi.com/coding/" "kimi-k2.5" $kimiKey "ANTHROPIC_API_KEY" }
                elseif ($existingKimi) { Log-Info "Kept existing Kimi key" }
                else { Log-Warn "Skipped Kimi (empty key)" }
            }
            default { Log-Warn "Unknown choice: $c" }
        }
    }
}

function Configure-DangerousMode {
    Write-Host ""
    Write-Host "Safety Mode Configuration" -ForegroundColor Blue
    Write-Host ""
    Write-Host "--dangerously-skip-permissions bypasses Claude's safety prompts." -ForegroundColor Yellow
    Write-Host "  1) Enable by default"
    Write-Host "  2) Disable by default (use flag manually)"
    Write-Host ""
    $choice = Read-Host "Choose [1/2] (default: 2)"
    $autoDanger = if ($choice -eq "1") { "true" } else { "false" }
    if ($autoDanger -eq "true") { Log-Success "Auto --dangerously-skip-permissions: ENABLED" }
    else { Log-Info "Use: claude-glm --dangerously-skip-permissions to enable per-session" }
    $configFile = Join-Path $ClaudeConfigDir ".model-switcher-config"
    Set-Content -Path $configFile -Value "AUTO_DANGEROUS_MODE=$autoDanger" -Encoding UTF8
}

function Ensure-PathHint {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -like "*$LocalBinDir*") {
        Log-Success "$LocalBinDir is already in PATH"
        return
    }
    Log-Info "Adding $LocalBinDir to User PATH..."
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$LocalBinDir", "User")
    $env:Path = "$env:Path;$LocalBinDir"
    Log-Success "Added to PATH. Restart terminal for full effect."
}

function Set-EnvironmentVariables {
    Log-Info "Setting environment variables..."

    # Set CLAUDE_CONFIG_DIR
    $existingClaudeConfig = [Environment]::GetEnvironmentVariable("CLAUDE_CONFIG_DIR", "User")
    if ($existingClaudeConfig -eq $ClaudeConfigDir) {
        Log-Success "CLAUDE_CONFIG_DIR already set to $ClaudeConfigDir"
    } else {
        [Environment]::SetEnvironmentVariable("CLAUDE_CONFIG_DIR", $ClaudeConfigDir, "User")
        $env:CLAUDE_CONFIG_DIR = $ClaudeConfigDir
        Log-Success "Set CLAUDE_CONFIG_DIR = $ClaudeConfigDir"
    }
}

function Add-ToPowerShellProfile {
    # Add to PowerShell profile for reliable PATH inclusion
    $profilePath = $PROFILE.CurrentUserCurrentHost
    $profileDir = Split-Path $profilePath -Parent
    $pathEntry = $LocalBinDir -replace '\\', '\\'

    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    $profileContent = ""
    if (Test-Path $profilePath) {
        $profileContent = Get-Content $profilePath -Raw
    }

    $marker = "# Claude Code Model Switcher PATH"
    if ($profileContent -like "*$marker*") {
        Log-Success "PowerShell profile already configured"
        return
    }

    $addition = @"

$marker
if (`$env:Path -notlike "*$pathEntry*") {
    `$env:Path = "$LocalBinDir;`$env:Path"
}
"@

    Add-Content -Path $profilePath -Value $addition -NoNewline
    Log-Success "Added PATH to PowerShell profile: $profilePath"

    # Apply to current session immediately
    if ($env:Path -notlike "*$LocalBinDir*") {
        $env:Path = "$LocalBinDir;$env:Path"
        Log-Success "Applied to current session"
    }
}

function Show-PostInstall {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Apply to current session (run this command):" -ForegroundColor Yellow
    Write-Host '  $env:Path = "' -NoNewline; Write-Host "$LocalBinDir" -ForegroundColor Cyan -NoNewline; Write-Host ';$env:Path"'
    Write-Host ""
    Write-Host "New PowerShell sessions will work automatically." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Available commands: claude, claude-glm, claude-kimi" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================
# Main
# ============================================

Write-Host ""
Write-Host "Claude Code Model Switcher - Windows Installer" -ForegroundColor Blue
Write-Host ""

try {
    Check-Prerequisites
    Create-InstallDir
    Install-MainScript
    Install-LegacyShims
    Install-WrapperScripts
    Configure-ApiKeys
    Configure-DangerousMode
    Set-EnvironmentVariables
    Add-ToPowerShellProfile
    Ensure-PathHint
    Show-PostInstall
} catch {
    Log-Error $_.Exception.Message
}
