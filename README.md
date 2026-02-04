# Claude Code Model Switcher

Convenient CLI commands to switch between different Claude Code models with ease.

## Features

- **Simple Commands**: `claude`, `claude-glm`, `claude-kimi`, `claude-deepseek`, etc.
- **Auto Configuration**: Automatically loads API keys from config file
- **Easy Installation**: One-line installer script
- **Multiple Models**: Support for 7+ AI providers (Claude, GLM, Kimi, DeepSeek, Qwen, MiniMax, OpenRouter)
- **Interactive Setup**: Easy configuration menu

## Installation

```bash
# Clone and install
git clone https://github.com/your-username/claude-code-model-switcher.git
cd claude-code-model-switcher
./install.sh
```

## Usage

```bash
# Default Claude (passes --dangerously-skip-permissions by default)
claude

# GLM 4.7
claude-glm

# Kimi 2.5
claude-kimi

# DeepSeek
claude-deepseek

# Qwen Plus
claude-qwen

# MiniMax M2
claude-minimax

# OpenRouter (100+ models)
claude-openrouter
```

## Setup

The installer can optionally prompt you for only the API keys you want to configure.

It writes provider settings files in `~/.claude/` (compatible with the referenced gist):

- `~/.claude/zai_settings.json` (GLM 4.7)
- `~/.claude/kimi_settings.json` (Kimi 2.5)

Kimi expects:
- `ANTHROPIC_BASE_URL=https://api.kimi.com/coding/`
- `ANTHROPIC_API_KEY=...`

For other providers, keep using `ANTHROPIC_AUTH_TOKEN` (no change).

You can re-run configuration anytime:

```bash
claude-model setup     # menu (repeatable)
claude-model config    # configure one provider
```

If you previously installed an older version that used shell aliases like `alias claude-glm='~/.claude/claude-glm.sh'`,
the installer also writes legacy shim scripts so your existing shell keeps working.

## Available Models

| Command | Model | Provider |
|---------|--------|----------|
| `claude` | Sonnet 4.5 | Anthropic |
| `claude-glm` | GLM 4.7 | Z.AI |
| `claude-kimi` | Kimi 2.5 | Moonshot AI |
| `claude-deepseek` | DeepSeek Chat | DeepSeek |
| `claude-qwen` | Qwen Plus | Alibaba |
| `claude-minimax` | MiniMax M2 | MiniMax |
| `claude-openrouter` | 100+ models | OpenRouter |

## Pricing Comparison

| Provider | Input $/1M | Output $/1M | vs Claude |
|----------|-----------|-------------|----------|
| Claude Sonnet 4.5 | $3.00 | $15.00 | 1x |
| DeepSeek | $0.28 | $0.42 | **~90% cheaper** |
| GLM 4.6 | $0.60 | $2.20 | ~80% cheaper |
| Kimi K2 | $0.14 | $2.49 | ~85% cheaper |
| Qwen Plus | $0.22 | $0.95 | ~90% cheaper |
| MiniMax M2 | $0.30 | $1.20 | ~90% cheaper |

## Configuration

Configuration is stored in `~/.claude/config.json`:

```json
{
  "claude": {
    "authToken": "sk-ant-your-key",
    "baseUrl": "https://api.anthropic.com"
  },
  "glm": {
    "authToken": "sk-glm-your-key",
    "baseUrl": "https://api.z.ai/api/coding/paas/v4"
  },
  "kimi": {
    "authToken": "sk-kimi-your-key",
    "baseUrl": "https://api.moonshot.ai/v1"
  },
  "deepseek": {
    "authToken": "sk-deepseek-your-key",
    "baseUrl": "https://api.deepseek.com/anthropic"
  },
  "qwen": {
    "authToken": "sk-qwen-your-key",
    "baseUrl": "https://dashscope-intl.aliyuncs.com/apps/anthropic"
  },
  "minimax": {
    "authToken": "sk-minimax-your-key",
    "baseUrl": "https://api.minimax.io/anthropic"
  },
  "openrouter": {
    "authToken": "sk-or-your-key",
    "baseUrl": "https://openrouter.ai/api"
  }
}
```

### Get API Keys

| Provider | URL |
|----------|-----|
| **Claude** | https://console.anthropic.com/ |
| **GLM** | https://open.bigmodel.cn/ |
| **Kimi** | https://platform.moonshot.ai/ |
| **DeepSeek** | https://platform.deepseek.com/ |
| **Qwen** | https://dashscope-intl.aliyuncs.com/ |
| **MiniMax** | https://platform.minimax.io/ |
| **OpenRouter** | https://openrouter.ai/keys |

## Management Commands

```bash
# Setup all API keys at once (interactive)
claude-model setup

# Configure specific model (interactive menu)
claude-model config

# Configure specific model directly
claude-model config deepseek

# Show current default model
claude-model current

# List all available models
claude-model list

# Set default model without running
claude-model set claude-opus

# Run with specific model
claude-model use claude-glm
```

## How It Works

Each command uses its own dedicated script:

```
claude-glm → ~/.claude/claude-glm.sh → Sets GLM env vars → Launches Claude Code
claude → ~/.claude/claude.sh → Uses Claude env vars → Launches Claude Code
```

The wrapper scripts:
1. Load configuration from `~/.claude/config.json`
2. Set environment variables (`ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL`, model settings)
3. Find and launch the original Claude Code binary

## Uninstall

To completely remove Claude Code Model Switcher:

```bash
cd claude-code-model-switcher
./uninstall.sh
```

## License

MIT
