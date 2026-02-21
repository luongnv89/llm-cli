#!/bin/bash
# llm-cli: Cross-Platform Installation Script
# Supports: macOS (Apple Silicon/Intel), Linux (NVIDIA/CPU-only), Windows (WSL)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/luongnv89/llm-cli/main/scripts/install.sh | bash
#   OR
#   ./scripts/install.sh [OPTIONS]
#
# Options:
#   --prefix DIR       Install to DIR (default: ~/.local/bin)
#   --no-deps          Skip dependency installation
#   --no-completions   Skip shell completion installation
#   --uninstall        Remove llm-cli
#   --verify           Verify existing installation
#   --help             Show this help

set -euo pipefail

#######################################
# Configuration
#######################################

readonly VERSION="1.1.3"
readonly GITHUB_REPO="luongnv89/llm-cli"
readonly GITHUB_URL="https://github.com/${GITHUB_REPO}"

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly RESET='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' RESET=''
fi

# Installation paths
INSTALL_PREFIX="${HOME}/.local/bin"
LLM_CLI_HOME="${HOME}/.local/share/llm-cli"
CONFIG_DIR="${HOME}/.config/llm-cli"

# Feature flags
INSTALL_DEPS=1
INSTALL_COMPLETIONS=1

# Detect if running from curl pipe (stdin is not a terminal)
IS_PIPED=0
if [[ ! -t 0 ]]; then
    IS_PIPED=1
fi

#######################################
# Logging Functions
#######################################

log_info() { echo -e "${CYAN}[INFO]${RESET} $*"; }
log_ok() { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step() { echo -e "${BLUE}[$1/$2]${RESET} $3"; }

#######################################
# Platform Detection
#######################################

detect_os() {
    local os
    os=$(uname -s)
    case "$os" in
        Darwin) echo "macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        MINGW* | MSYS* | CYGWIN*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64 | amd64) echo "x86_64" ;;
        arm64 | aarch64) echo "arm64" ;;
        armv7l) echo "armv7" ;;
        *) echo "$arch" ;;
    esac
}

detect_gpu() {
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        echo "nvidia"
    elif [[ "$(detect_os)" == "macos" ]] && [[ "$(detect_arch)" == "arm64" ]]; then
        echo "metal"
    else
        echo "none"
    fi
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # Parse ID= without sourcing (avoids readonly variable conflicts)
        grep -m1 "^ID=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "unknown"
    else
        echo "unknown"
    fi
}

get_platform_name() {
    local os arch gpu
    os=$(detect_os)
    arch=$(detect_arch)
    gpu=$(detect_gpu)

    case "$os" in
        macos)
            if [[ "$arch" == "arm64" ]]; then
                echo "macos-arm64-metal"
            else
                echo "macos-x86_64"
            fi
            ;;
        linux | wsl)
            if [[ "$gpu" == "nvidia" ]]; then
                echo "linux-${arch}-nvidia"
            else
                echo "linux-${arch}-cpu"
            fi
            ;;
        *) echo "$os-$arch" ;;
    esac
}

# Simplified platform for llm-cli
get_llm_platform() {
    local os gpu
    os=$(detect_os)
    gpu=$(detect_gpu)

    case "$os" in
        macos) echo "macos" ;;
        linux | wsl)
            if [[ "$gpu" == "nvidia" ]]; then
                echo "linux-nvidia"
            else
                echo "linux-cpu"
            fi
            ;;
        *) echo "linux-cpu" ;;
    esac
}

#######################################
# Dependency Management
#######################################

get_package_manager() {
    local os
    os=$(detect_os)

    case "$os" in
        macos)
            if command -v brew &>/dev/null; then
                echo "brew"
            else
                echo "none"
            fi
            ;;
        linux | wsl)
            if command -v apt &>/dev/null; then
                echo "apt"
            elif command -v dnf &>/dev/null; then
                echo "dnf"
            elif command -v yum &>/dev/null; then
                echo "yum"
            elif command -v pacman &>/dev/null; then
                echo "pacman"
            elif command -v zypper &>/dev/null; then
                echo "zypper"
            else
                echo "none"
            fi
            ;;
        *) echo "none" ;;
    esac
}

check_dependency() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null
}

install_homebrew() {
    if ! command -v brew &>/dev/null; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add to PATH for current session
        if [[ "$(detect_arch)" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
}

install_llama_cpp() {
    local platform pkg_mgr
    platform=$(get_llm_platform)
    pkg_mgr=$(get_package_manager)

    log_info "Installing llama.cpp..."

    case "$platform" in
        macos)
            if [[ "$pkg_mgr" == "brew" ]]; then
                brew install llama.cpp
            else
                log_error "Homebrew required for macOS. Install from https://brew.sh"
                return 1
            fi
            ;;
        linux-nvidia)
            install_llama_cpp_from_source "cuda"
            ;;
        linux-cpu)
            install_llama_cpp_from_source "cpu"
            ;;
    esac
}

install_llama_cpp_from_source() {
    local mode="${1:-cpu}"
    local build_dir="/tmp/llama-cpp-build-$$"

    log_info "Building llama.cpp from source (mode: $mode)..."

    # Install build dependencies
    local pkg_mgr
    pkg_mgr=$(get_package_manager)

    case "$pkg_mgr" in
        apt)
            sudo apt update
            sudo apt install -y build-essential cmake git curl
            ;;
        dnf | yum)
            sudo "$pkg_mgr" install -y gcc-c++ cmake git curl make
            ;;
        pacman)
            sudo pacman -S --noconfirm base-devel cmake git curl
            ;;
        zypper)
            sudo zypper install -y gcc-c++ cmake git curl make
            ;;
        *)
            log_error "Unsupported package manager. Please install: build-essential, cmake, git, curl"
            return 1
            ;;
    esac

    # Clone and build
    mkdir -p "$build_dir"
    git clone --depth 1 https://github.com/ggerganov/llama.cpp "$build_dir"
    cd "$build_dir"

    if [[ "$mode" == "cuda" ]]; then
        cmake -B build -DGGML_CUDA=ON
    else
        cmake -B build
    fi

    cmake --build build --config Release -j "$(nproc)"

    # Install binaries
    sudo cp build/bin/llama-* /usr/local/bin/

    # Cleanup
    cd - >/dev/null
    rm -rf "$build_dir"

    log_ok "llama.cpp installed successfully"
}

install_optional_deps() {
    local pkg_mgr
    pkg_mgr=$(get_package_manager)

    log_info "Installing optional dependencies (jq, curl)..."

    case "$pkg_mgr" in
        brew)
            brew install jq curl 2>/dev/null || true
            ;;
        apt)
            sudo apt install -y jq curl 2>/dev/null || true
            ;;
        dnf | yum)
            sudo "$pkg_mgr" install -y jq curl 2>/dev/null || true
            ;;
        pacman)
            sudo pacman -S --noconfirm jq curl 2>/dev/null || true
            ;;
        zypper)
            sudo zypper install -y jq curl 2>/dev/null || true
            ;;
    esac
}

#######################################
# Installation Functions
#######################################

get_script_dir() {
    # Handle both direct execution and piped installation
    if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
        local dir
        dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # If we're in scripts/, go up one level
        if [[ "$(basename "$dir")" == "scripts" ]]; then
            echo "$(dirname "$dir")"
        else
            echo "$dir"
        fi
    else
        # Running from curl pipe - need to clone
        echo ""
    fi
}

install_from_git() {
    local install_dir="$1"

    log_info "Cloning llm-cli from GitHub..." >&2

    local clone_dir="${HOME}/.local/share/llm-cli/source"
    mkdir -p "$(dirname "$clone_dir")"

    if [[ -d "$clone_dir" ]]; then
        log_info "Updating existing installation..." >&2
        cd "$clone_dir"
        git pull --ff-only origin main </dev/null >&2
    else
        git clone "$GITHUB_URL" "$clone_dir" </dev/null >&2
    fi

    echo "$clone_dir"
}

install_symlink() {
    local source_dir="$1"
    local install_dir="$2"

    mkdir -p "$install_dir"

    local symlink_path="$install_dir/llm-cli"

    # Remove existing
    if [[ -L "$symlink_path" ]] || [[ -e "$symlink_path" ]]; then
        rm -f "$symlink_path"
    fi

    # Create symlink
    ln -s "$source_dir/bin/llm-cli" "$symlink_path"
    chmod +x "$source_dir/bin/llm-cli"

    echo "$symlink_path"
}

install_completions() {
    local source_dir="$1"
    local shell_type

    # Detect shell
    shell_type=$(basename "${SHELL:-bash}")

    log_info "Installing shell completions for $shell_type..."

    case "$shell_type" in
        bash)
            local bash_comp_dir="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
            if [[ -f "$source_dir/completions/llm-cli.bash" ]]; then
                mkdir -p "$bash_comp_dir"
                cp "$source_dir/completions/llm-cli.bash" "$bash_comp_dir/llm-cli"
                log_ok "Bash completion: $bash_comp_dir/llm-cli"
            fi
            ;;
        zsh)
            local zsh_comp_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
            if [[ -f "$source_dir/completions/llm-cli.zsh" ]]; then
                mkdir -p "$zsh_comp_dir"
                cp "$source_dir/completions/llm-cli.zsh" "$zsh_comp_dir/_llm-cli"
                log_ok "Zsh completion: $zsh_comp_dir/_llm-cli"
            fi
            ;;
    esac
}

verify_installation() {
    local install_path="$1"
    local errors=0

    log_info "Verifying installation..."

    # Check llm-cli exists and is executable
    if [[ -x "$install_path" ]]; then
        log_ok "llm-cli executable found: $install_path"
    else
        log_error "llm-cli not found or not executable: $install_path"
        errors=$((errors + 1))
    fi

    # Check llm-cli runs
    if "$install_path" --help &>/dev/null; then
        log_ok "llm-cli --help works"
    else
        log_error "llm-cli --help failed"
        errors=$((errors + 1))
    fi

    # Check llama-cli dependency
    if check_dependency llama-cli; then
        log_ok "llama-cli found: $(command -v llama-cli)"
    else
        log_warn "llama-cli not found - required for chat/benchmark features"
    fi

    # Check optional jq
    if check_dependency jq; then
        log_ok "jq found (optional)"
    else
        log_warn "jq not found - some statistics features may be limited"
    fi

    return $errors
}

check_path() {
    local install_dir="$1"

    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        log_warn "$install_dir is not in your PATH"
        echo ""
        echo "Add it to your shell profile:"
        echo ""

        local shell_type
        shell_type=$(basename "${SHELL:-bash}")

        case "$shell_type" in
            zsh)
                echo "  echo 'export PATH=\"$install_dir:\$PATH\"' >> ~/.zshrc"
                echo "  source ~/.zshrc"
                ;;
            bash)
                echo "  echo 'export PATH=\"$install_dir:\$PATH\"' >> ~/.bashrc"
                echo "  source ~/.bashrc"
                ;;
            fish)
                echo "  fish_add_path $install_dir"
                ;;
            *)
                echo "  export PATH=\"$install_dir:\$PATH\""
                ;;
        esac
        echo ""
        return 1
    fi
    return 0
}

#######################################
# Uninstall
#######################################

uninstall() {
    log_info "Uninstalling llm-cli..."

    local symlink_path="$INSTALL_PREFIX/llm-cli"
    local source_dir="$LLM_CLI_HOME/source"

    # Remove symlink
    if [[ -L "$symlink_path" ]] || [[ -e "$symlink_path" ]]; then
        rm -f "$symlink_path"
        log_ok "Removed: $symlink_path"
    fi

    # Remove source
    if [[ -d "$source_dir" ]]; then
        rm -rf "$source_dir"
        log_ok "Removed: $source_dir"
    fi

    # Remove completions
    local bash_comp="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions/llm-cli"
    local zsh_comp="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions/_llm-cli"

    [[ -f "$bash_comp" ]] && rm -f "$bash_comp" && log_ok "Removed: $bash_comp"
    [[ -f "$zsh_comp" ]] && rm -f "$zsh_comp" && log_ok "Removed: $zsh_comp"

    echo ""
    log_ok "llm-cli uninstalled successfully"
    echo ""
    echo "Note: Configuration and data preserved at:"
    echo "  Config:  $CONFIG_DIR"
    echo "  Data:    $LLM_CLI_HOME"
    echo "  Models:  ~/.cache/huggingface/hub/"
    echo ""
    echo "To remove all data: rm -rf $CONFIG_DIR $LLM_CLI_HOME"
}

#######################################
# Main Installation Flow
#######################################

show_help() {
    cat <<EOF
llm-cli Installation Script v${VERSION}

Usage: $0 [OPTIONS]

Options:
  --prefix DIR       Install to DIR (default: ~/.local/bin)
  --no-deps          Skip dependency installation
  --no-completions   Skip shell completion installation
  --uninstall        Remove llm-cli
  --verify           Verify existing installation
  --help             Show this help

Examples:
  # Standard installation
  ./scripts/install.sh

  # Install to custom directory
  ./scripts/install.sh --prefix /usr/local/bin

  # Install from curl
  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/scripts/install.sh | bash

  # Verify installation
  ./scripts/install.sh --verify

  # Uninstall
  ./scripts/install.sh --uninstall

EOF
}

main() {
    local do_uninstall=0
    local do_verify=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix)
                INSTALL_PREFIX="$2"
                shift 2
                ;;
            --no-deps)
                INSTALL_DEPS=0
                shift
                ;;
            --no-completions)
                INSTALL_COMPLETIONS=0
                shift
                ;;
            --uninstall)
                do_uninstall=1
                shift
                ;;
            --verify)
                do_verify=1
                shift
                ;;
            --help | -h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    echo ""
    echo -e "${BOLD}llm-cli Installer v${VERSION}${RESET}"
    echo "================================"
    echo ""

    # Handle uninstall
    if [[ $do_uninstall -eq 1 ]]; then
        uninstall
        exit 0
    fi

    # Handle verify
    if [[ $do_verify -eq 1 ]]; then
        if verify_installation "$INSTALL_PREFIX/llm-cli"; then
            exit 0
        else
            exit 1
        fi
    fi

    # Collect system info
    local os arch gpu platform distro pkg_mgr
    os=$(detect_os)
    arch=$(detect_arch)
    gpu=$(detect_gpu)
    platform=$(get_platform_name)
    distro=$(detect_distro)
    pkg_mgr=$(get_package_manager)

    echo "System Information:"
    echo "  OS:       $os ($distro)"
    echo "  Arch:     $arch"
    echo "  GPU:      $gpu"
    echo "  Platform: $platform"
    echo "  Pkg Mgr:  $pkg_mgr"
    echo ""

    # Check for existing installation
    if command -v llm-cli &>/dev/null; then
        local existing
        existing=$(command -v llm-cli)
        log_warn "llm-cli already installed at: $existing"
        echo ""
    fi

    local total_steps=5
    local step=0

    # Step 1: Check/Install Homebrew on macOS
    if [[ "$os" == "macos" ]] && [[ $INSTALL_DEPS -eq 1 ]]; then
        step=$((step + 1))
        log_step $step $total_steps "Checking Homebrew..."
        if ! command -v brew &>/dev/null; then
            install_homebrew
        else
            log_ok "Homebrew available"
        fi
    else
        step=$((step + 1))
        log_step $step $total_steps "Skipping package manager check"
    fi

    # Track missing dependencies for post-install guide
    local missing_llama=0
    local missing_jq=0
    local missing_curl=0

    # Step 2: Install/Check llama.cpp
    step=$((step + 1))
    log_step $step $total_steps "Checking llama.cpp..."
    if ! check_dependency llama-cli; then
        if [[ $INSTALL_DEPS -eq 1 ]] && [[ $IS_PIPED -eq 0 ]]; then
            install_llama_cpp
            # Re-check after install attempt
            if ! check_dependency llama-cli; then
                missing_llama=1
            fi
        else
            missing_llama=1
            log_warn "llama-cli not found (required for chat, benchmark, and serve)"
        fi
    else
        log_ok "llama-cli found: $(command -v llama-cli)"
    fi

    # Step 3: Install optional dependencies
    step=$((step + 1))
    log_step $step $total_steps "Checking optional dependencies..."
    if [[ $INSTALL_DEPS -eq 1 ]] && [[ $IS_PIPED -eq 0 ]]; then
        install_optional_deps
    else
        log_info "Skipped dependency installation (piped mode)"
    fi
    # Check optional deps regardless
    if ! check_dependency jq; then
        missing_jq=1
    fi
    if ! check_dependency curl; then
        missing_curl=1
    fi

    # Step 4: Install llm-cli
    step=$((step + 1))
    log_step $step $total_steps "Installing llm-cli..."

    local source_dir
    source_dir=$(get_script_dir)

    if [[ -z "$source_dir" ]]; then
        # Running from curl pipe
        source_dir=$(install_from_git "$INSTALL_PREFIX")
    fi

    local install_path
    install_path=$(install_symlink "$source_dir" "$INSTALL_PREFIX")
    log_ok "Installed: $install_path"

    # Step 5: Install completions
    step=$((step + 1))
    log_step $step $total_steps "Installing shell completions..."
    if [[ $INSTALL_COMPLETIONS -eq 1 ]]; then
        install_completions "$source_dir"
    else
        log_info "Skipped (--no-completions)"
    fi

    # Verify and show results
    echo ""
    verify_installation "$install_path" || true

    # Check if PATH needs updating
    local needs_path=0
    if [[ ":$PATH:" != *":$INSTALL_PREFIX:"* ]]; then
        needs_path=1
    fi

    # Show post-install guide if anything needs attention
    if [[ $missing_llama -eq 1 ]] || [[ $missing_jq -eq 1 ]] || [[ $missing_curl -eq 1 ]] || [[ $needs_path -eq 1 ]]; then
        echo ""
        echo -e "${BOLD}========================================${RESET}"
        echo -e "${BOLD} Post-Installation Steps${RESET}"
        echo -e "${BOLD}========================================${RESET}"
        local step_num=0

        # PATH setup
        if [[ $needs_path -eq 1 ]]; then
            step_num=$((step_num + 1))
            echo ""
            echo -e "${YELLOW}${step_num}. Add llm-cli to your PATH${RESET}"
            echo ""
            echo "   llm-cli was installed to ${BOLD}$INSTALL_PREFIX${RESET} which is not in your PATH."
            echo "   Add it by running:"
            echo ""

            local shell_type
            shell_type=$(basename "${SHELL:-bash}")
            case "$shell_type" in
                zsh)
                    echo "   echo 'export PATH=\"$INSTALL_PREFIX:\$PATH\"' >> ~/.zshrc"
                    echo "   source ~/.zshrc"
                    ;;
                bash)
                    echo "   echo 'export PATH=\"$INSTALL_PREFIX:\$PATH\"' >> ~/.bashrc"
                    echo "   source ~/.bashrc"
                    ;;
                fish)
                    echo "   fish_add_path $INSTALL_PREFIX"
                    ;;
                *)
                    echo "   export PATH=\"$INSTALL_PREFIX:\$PATH\""
                    ;;
            esac
        fi

        # llama.cpp installation
        if [[ $missing_llama -eq 1 ]]; then
            step_num=$((step_num + 1))
            echo ""
            echo -e "${YELLOW}${step_num}. Install llama.cpp (required)${RESET}"
            echo ""
            echo "   llama-cli is needed for chat, benchmark, and serve commands."
            echo ""

            local llm_platform
            llm_platform=$(get_llm_platform)

            case "$llm_platform" in
                macos)
                    echo "   ${BOLD}macOS (Homebrew):${RESET}"
                    echo "   brew install llama.cpp"
                    ;;
                linux-nvidia)
                    echo "   ${BOLD}Linux with NVIDIA GPU:${RESET}"
                    echo "   # Install build tools"
                    echo "   sudo apt install -y build-essential cmake git curl"
                    echo ""
                    echo "   # Build with CUDA support"
                    echo "   git clone --depth 1 https://github.com/ggerganov/llama.cpp /tmp/llama-build"
                    echo "   cd /tmp/llama-build"
                    echo "   cmake -B build -DGGML_CUDA=ON"
                    echo "   cmake --build build --config Release -j \$(nproc)"
                    echo "   sudo cp build/bin/llama-* /usr/local/bin/"
                    echo "   cd - && rm -rf /tmp/llama-build"
                    ;;
                linux-cpu)
                    echo "   ${BOLD}Linux (CPU):${RESET}"
                    echo "   # Install build tools"
                    echo "   sudo apt install -y build-essential cmake git curl"
                    echo ""
                    echo "   # Build from source"
                    echo "   git clone --depth 1 https://github.com/ggerganov/llama.cpp /tmp/llama-build"
                    echo "   cd /tmp/llama-build"
                    echo "   cmake -B build"
                    echo "   cmake --build build --config Release -j \$(nproc)"
                    echo "   sudo cp build/bin/llama-* /usr/local/bin/"
                    echo "   cd - && rm -rf /tmp/llama-build"
                    ;;
            esac
            echo ""
            echo "   More info: https://github.com/ggerganov/llama.cpp#build"
        fi

        # Optional dependencies
        if [[ $missing_jq -eq 1 ]] || [[ $missing_curl -eq 1 ]]; then
            step_num=$((step_num + 1))
            local missing_pkgs=""
            [[ $missing_jq -eq 1 ]] && missing_pkgs="jq"
            [[ $missing_curl -eq 1 ]] && missing_pkgs="${missing_pkgs:+$missing_pkgs }curl"

            echo ""
            echo -e "${YELLOW}${step_num}. Install optional dependencies${RESET}"
            echo ""
            [[ $missing_jq -eq 1 ]] && echo "   - ${BOLD}jq${RESET}: Needed for statistics and JSON processing"
            [[ $missing_curl -eq 1 ]] && echo "   - ${BOLD}curl${RESET}: Needed for model search and download"
            echo ""

            case "$(detect_os)" in
                macos)
                    echo "   brew install $missing_pkgs"
                    ;;
                linux | wsl)
                    echo "   sudo apt install -y $missing_pkgs"
                    ;;
            esac
        fi

        echo ""
        echo -e "${BOLD}========================================${RESET}"
    fi

    # Quick start (always shown)
    echo ""
    echo -e "${BOLD}Quick Start:${RESET}"
    echo "  llm-cli --help              Show help"
    echo "  llm-cli config              Show configuration"
    echo "  llm-cli search llama        Search for models"
    echo "  llm-cli chat                Start a conversation"
    echo ""

    log_ok "Installation complete!"
    echo ""
}

# Run main
main "$@"
