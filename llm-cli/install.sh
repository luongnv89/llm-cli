#!/bin/bash
# llm-cli: Installation script
# Installs llm-cli to user's PATH
# Supports macOS and Linux (Ubuntu)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default install location
INSTALL_DIR="${HOME}/.local/bin"

# Detect platform
detect_platform() {
    local os
    os=$(uname -s)
    if [[ "$os" == "Darwin" ]]; then
        echo "macos"
    elif [[ "$os" == "Linux" ]] && command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        echo "linux-nvidia"
    else
        echo "linux-cpu"
    fi
}

PLATFORM=$(detect_platform)

echo ""
echo -e "${BOLD}llm-cli Installer${RESET}"
echo "=================="
echo ""
echo -e "Detected platform: ${CYAN}$PLATFORM${RESET}"
echo ""

# Check for existing installation
if command -v llm-cli &>/dev/null; then
    existing=$(command -v llm-cli)
    echo -e "${YELLOW}[WARN]${RESET} llm-cli already installed at: $existing"
    echo ""
fi

# Pre-flight checks
echo -e "${CYAN}[1/4]${RESET} Checking dependencies..."

# Check for llama.cpp
if ! command -v llama-cli &>/dev/null; then
    echo -e "${YELLOW}[WARN]${RESET} llama-cli not found."
    echo ""
    case "$PLATFORM" in
        macos)
            echo "Install llama.cpp with Homebrew:"
            echo "  brew install llama.cpp"
            ;;
        linux-nvidia)
            echo "Build llama.cpp from source with CUDA support:"
            echo ""
            echo "  # Install dependencies"
            echo "  sudo apt update && sudo apt install -y build-essential cmake git"
            echo ""
            echo "  # Clone and build with CUDA"
            echo "  git clone https://github.com/ggerganov/llama.cpp"
            echo "  cd llama.cpp"
            echo "  cmake -B build -DGGML_CUDA=ON"
            echo "  cmake --build build --config Release"
            echo ""
            echo "  # Add to PATH"
            echo "  sudo cp build/bin/llama-* /usr/local/bin/"
            ;;
        linux-cpu)
            echo "Build llama.cpp from source:"
            echo ""
            echo "  # Install dependencies"
            echo "  sudo apt update && sudo apt install -y build-essential cmake git"
            echo ""
            echo "  # Clone and build"
            echo "  git clone https://github.com/ggerganov/llama.cpp"
            echo "  cd llama.cpp"
            echo "  cmake -B build"
            echo "  cmake --build build --config Release"
            echo ""
            echo "  # Add to PATH"
            echo "  sudo cp build/bin/llama-* /usr/local/bin/"
            ;;
    esac
    echo ""
    echo -e "${YELLOW}After installing llama.cpp, run this installer again.${RESET}"
    echo ""
fi

# Create install directory
echo -e "${CYAN}[2/4]${RESET} Creating install directory..."
mkdir -p "$INSTALL_DIR"

# Create symlink to bin/llm-cli
echo -e "${CYAN}[3/4]${RESET} Installing llm-cli..."

SYMLINK_PATH="$INSTALL_DIR/llm-cli"

if [ -L "$SYMLINK_PATH" ] || [ -e "$SYMLINK_PATH" ]; then
    rm -f "$SYMLINK_PATH"
fi

ln -s "$SCRIPT_DIR/bin/llm-cli" "$SYMLINK_PATH"
chmod +x "$SCRIPT_DIR/bin/llm-cli"

echo -e "${CYAN}[4/4]${RESET} Checking PATH..."

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo -e "${YELLOW}[NOTE]${RESET} $INSTALL_DIR is not in your PATH."
    echo ""
    echo "Add it to your shell profile:"
    echo ""

    if [ -f "$HOME/.zshrc" ]; then
        echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
        echo "  source ~/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
        echo "  source ~/.bashrc"
    else
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    echo ""
fi

echo ""
echo -e "${GREEN}[OK]${RESET} Installation complete!"
echo ""
echo "Installed to: $SYMLINK_PATH"
echo "Platform:     $PLATFORM"
echo ""

# Platform-specific post-install instructions
case "$PLATFORM" in
    macos)
        echo -e "${BOLD}Quick Start (macOS):${RESET}"
        echo "  llm-cli --help          Show help"
        echo "  llm-cli search llama    Search for models"
        echo "  llm-cli models list     List cached models"
        echo "  llm-cli chat            Start a conversation"
        ;;
    linux-nvidia)
        echo -e "${BOLD}Quick Start (Linux + NVIDIA GPU):${RESET}"
        echo "  llm-cli --help          Show help"
        echo "  llm-cli config          Verify platform detection"
        echo "  llm-cli search llama    Search for models"
        echo "  llm-cli bench           Run GPU benchmark"
        echo ""
        echo -e "${BOLD}Optimal Performance:${RESET}"
        echo "  Default threads: 10 (optimized for DGX Spark P-cores)"
        echo "  GPU layers: 99 (full GPU offload)"
        echo "  Adjust in: ~/.config/llm-cli/config"
        ;;
    linux-cpu)
        echo -e "${BOLD}Quick Start (Linux CPU):${RESET}"
        echo "  llm-cli --help          Show help"
        echo "  llm-cli search llama    Search for models"
        echo "  llm-cli models list     List cached models"
        echo "  llm-cli chat            Start a conversation"
        echo ""
        echo -e "${YELLOW}Note: Running in CPU-only mode. For GPU acceleration,${RESET}"
        echo -e "${YELLOW}install NVIDIA drivers and rebuild llama.cpp with CUDA.${RESET}"
        ;;
esac
echo ""

# Install bash completion if possible
BASH_COMPLETION_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
if [ -d "$(dirname "$BASH_COMPLETION_DIR")" ] || [ -d "/etc/bash_completion.d" ]; then
    if [ -f "$SCRIPT_DIR/completions/llm-cli.bash" ]; then
        mkdir -p "$BASH_COMPLETION_DIR"
        cp "$SCRIPT_DIR/completions/llm-cli.bash" "$BASH_COMPLETION_DIR/llm-cli"
        echo "Bash completion installed to: $BASH_COMPLETION_DIR/llm-cli"
    fi
fi

# Install zsh completion if possible
ZSH_COMPLETION_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
if [ -f "$SCRIPT_DIR/completions/llm-cli.zsh" ]; then
    mkdir -p "$ZSH_COMPLETION_DIR"
    cp "$SCRIPT_DIR/completions/llm-cli.zsh" "$ZSH_COMPLETION_DIR/_llm-cli"
    echo "Zsh completion installed to: $ZSH_COMPLETION_DIR/_llm-cli"
fi

echo ""
