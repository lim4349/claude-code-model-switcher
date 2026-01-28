# Claude Code Model Switcher

Convenient CLI commands to switch between different Claude Code models with ease.

## Features

- **Simple Commands**: `claude`, `claude-glm`, `claude-opus`, `claude-sonnet`, etc.
- **Auto Configuration**: Automatically configures the default model for each command
- **Shell Completion**: Bash and Zsh completion support
- **Easy Installation**: One-line installer script
- **Model Presets**: Pre-configured model aliases for quick access

## Installation

```bash
# Clone and install
git clone https://github.com/your-username/claude-code-model-switcher.git
cd claude-code-model-switcher
./install.sh

# Or one-line installer
curl -fsSL https://raw.githubusercontent.com/your-username/claude-code-model-switcher/main/install.sh | bash
```

## Usage

```bash
# Default Claude (Opus 4.5)
claude

# GLM 4.7
claude-glm

# Sonnet 4.5
claude-sonnet

# Haiku 4.5
claude-haiku

# Custom model
claude-model claude-opus-4-5-20250114
```

## Available Commands

| Command | Default Model |
|---------|--------------|
| `claude` | `claude-opus-4-5-20251101` |
| `claude-glm` | `glm-4.7` |
| `claude-opus` | `claude-opus-4-5-20251101` |
| `claude-sonnet` | `claude-sonnet-4-5-20250515` |
| `claude-haiku` | `claude-haiku-4-5-20250114` |
| `claude-model <model>` | Custom model |

## Development

```bash
# Install in development mode
./install.sh --dev

# Run tests
./test.sh
```

## License

MIT
