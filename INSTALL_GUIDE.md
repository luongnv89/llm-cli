# llm-cli Installation Guide

Cross-platform installation guide for llm-cli.

## Quick Install

### One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/luongnv89/llm-cli/main/scripts/install.sh | bash
```

### From Git Clone

```bash
git clone https://github.com/luongnv89/llm-cli.git
cd llm-cli
./scripts/install.sh
```

## Platform-Specific Instructions

### macOS (Apple Silicon / Intel)

Prerequisites: Homebrew

```bash
# Install Homebrew if not present
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Option 1: Full automated install
./scripts/install.sh

# Option 2: Manual install
brew install llama.cpp jq
./scripts/install.sh --no-deps
```

**What gets installed:**
- llama.cpp via Homebrew
- llm-cli symlinked to `~/.local/bin/llm-cli`
- Shell completions for bash/zsh

### Linux + NVIDIA GPU (DGX Spark, RTX, etc.)

```bash
# Full automated install (builds llama.cpp with CUDA)
./scripts/install.sh

# This will:
# 1. Install build dependencies (cmake, git, etc.)
# 2. Clone and build llama.cpp with CUDA support
# 3. Install llm-cli
```

**Requirements:**
- NVIDIA drivers installed
- CUDA toolkit (detected automatically)
- sudo access for installing dependencies

### Linux CPU-Only

```bash
# Full automated install
./scripts/install.sh

# This will:
# 1. Install build dependencies
# 2. Clone and build llama.cpp (CPU-only)
# 3. Install llm-cli
```

### Windows (WSL)

Run in WSL2 with Ubuntu:

```bash
# Inside WSL
./scripts/install.sh
```

For NVIDIA GPU support in WSL2, ensure you have:
- Windows 11 or Windows 10 21H2+
- NVIDIA GPU drivers for WSL
- WSL2 with Ubuntu

## Installation Options

| Option | Description |
|--------|-------------|
| `--prefix DIR` | Install to DIR (default: `~/.local/bin`) |
| `--no-deps` | Skip dependency installation |
| `--no-completions` | Skip shell completion installation |
| `--uninstall` | Remove llm-cli |
| `--verify` | Verify existing installation |
| `--help` | Show help |

### Examples

```bash
# Install to system-wide location
sudo ./scripts/install.sh --prefix /usr/local/bin

# Install without dependencies (you manage them)
./scripts/install.sh --no-deps

# Verify installation
./scripts/install.sh --verify

# Uninstall
./scripts/install.sh --uninstall
```

## Post-Installation Setup

### Add to PATH

If `~/.local/bin` is not in your PATH, add it:

**Zsh (~/.zshrc):**
```bash
export PATH="$HOME/.local/bin:$PATH"
```

**Bash (~/.bashrc):**
```bash
export PATH="$HOME/.local/bin:$PATH"
```

**Fish (~/.config/fish/config.fish):**
```fish
fish_add_path $HOME/.local/bin
```

### Shell Completions

Completions are installed automatically. To enable:

**Bash:**
```bash
source ~/.local/share/bash-completion/completions/llm-cli
```

**Zsh:** Add to `~/.zshrc`:
```zsh
fpath=(~/.local/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit
```

## Verification

After installation, verify everything works:

```bash
# Check llm-cli
llm-cli --help

# Check configuration
llm-cli config

# Verify llama.cpp
llama-cli --version
```

## Troubleshooting

### "llm-cli: command not found"

Your PATH doesn't include `~/.local/bin`. Add it to your shell profile (see Post-Installation Setup).

### "llama-cli not found"

llama.cpp isn't installed. Run:

```bash
# macOS
brew install llama.cpp

# Linux
./scripts/install.sh  # Will build from source
```

### CUDA Not Detected

If you have an NVIDIA GPU but CUDA isn't detected:

1. Check NVIDIA drivers: `nvidia-smi`
2. Install CUDA toolkit
3. Rebuild llama.cpp:
   ```bash
   cd ~/.local/share/llm-cli/source
   ./scripts/install.sh  # Will detect and rebuild with CUDA
   ```

### Permission Denied

If you get permission errors:

```bash
# Option 1: Use sudo for system-wide install
sudo ./scripts/install.sh --prefix /usr/local/bin

# Option 2: Fix local bin permissions
mkdir -p ~/.local/bin
chmod 755 ~/.local/bin
```

## Uninstallation

```bash
# Remove llm-cli
./scripts/install.sh --uninstall

# Optionally remove all data
rm -rf ~/.config/llm-cli
rm -rf ~/.local/share/llm-cli
rm -rf ~/.cache/llm-cli

# Remove cached models (warning: large!)
rm -rf ~/.cache/huggingface/hub
```

## File Locations

| Path | Description |
|------|-------------|
| `~/.local/bin/llm-cli` | Main executable (symlink) |
| `~/.local/share/llm-cli/source` | Source code |
| `~/.config/llm-cli/config` | Configuration file |
| `~/.local/share/llm-cli/stats.json` | Usage statistics |
| `~/.local/share/llm-cli/benchmarks/` | Benchmark reports |
| `~/.cache/huggingface/hub/` | Downloaded models |

## Updating

```bash
# Pull latest changes
cd ~/.local/share/llm-cli/source
git pull origin main

# Or re-run installer
./scripts/install.sh
```
