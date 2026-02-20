#!/bin/bash
# llm-cli: Uninstall Script
# Cleanly removes llm-cli, its data, and optionally downloaded models
#
# Usage:
#   ./scripts/uninstall.sh [OPTIONS]
#
# Options:
#   --keep-models      Keep downloaded HuggingFace models
#   --keep-config      Keep configuration files
#   --yes              Skip confirmation prompts
#   --help             Show this help

set -euo pipefail

#######################################
# Configuration
#######################################

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly RESET='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' CYAN='' BOLD='' DIM='' RESET=''
fi

# XDG paths
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"

# Directories to remove
INSTALL_PREFIX="${HOME}/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME}/llm-cli"
DATA_DIR="${XDG_DATA_HOME}/llm-cli"
CACHE_DIR="${XDG_CACHE_HOME}/llm-cli"
BENCHMARK_DIR="${XDG_DATA_HOME}/llm-cli/benchmarks"
HF_CACHE_DIR="${HF_HOME:-$HOME/.cache/huggingface}/hub"

# Completion paths
BASH_COMP_DIR="${XDG_DATA_HOME}/bash-completion/completions"
ZSH_COMP_DIR="${XDG_DATA_HOME}/zsh/site-functions"

# Flags
KEEP_MODELS=0
KEEP_CONFIG=0
AUTO_YES=0

#######################################
# Logging
#######################################

log_info() { echo -e "${CYAN}[INFO]${RESET} $*"; }
log_ok() { echo -e "${GREEN}  ✓${RESET} $*"; }
log_skip() { echo -e "${DIM}  - $* (not found)${RESET}"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

#######################################
# Helpers
#######################################

# Format bytes to human-readable size
format_size() {
    local bytes="$1"
    if [[ "$bytes" -ge 1073741824 ]]; then
        echo "$(echo "scale=1; $bytes / 1073741824" | bc) GB"
    elif [[ "$bytes" -ge 1048576 ]]; then
        echo "$(echo "scale=1; $bytes / 1048576" | bc) MB"
    elif [[ "$bytes" -ge 1024 ]]; then
        echo "$(echo "scale=0; $bytes / 1024" | bc) KB"
    else
        echo "$bytes bytes"
    fi
}

# Get directory size in bytes (cross-platform)
get_dir_size() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "0"
        return
    fi
    if [[ "$(uname -s)" == "Darwin" ]]; then
        du -sk "$dir" 2>/dev/null | awk '{print $1 * 1024}'
    else
        du -sb "$dir" 2>/dev/null | awk '{print $1}'
    fi
}

# Prompt for confirmation
confirm() {
    local prompt="$1"
    if [[ $AUTO_YES -eq 1 ]]; then
        return 0
    fi
    echo ""
    echo -ne "${BOLD}${prompt}${RESET} [y/N] "
    local reply
    read -r reply
    case "$reply" in
        [yY] | [yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Safely remove a file or directory
remove_item() {
    local path="$1"
    local label="$2"

    if [[ -L "$path" ]]; then
        rm -f "$path"
        log_ok "Removed symlink: $label"
    elif [[ -f "$path" ]]; then
        rm -f "$path"
        log_ok "Removed file: $label"
    elif [[ -d "$path" ]]; then
        rm -rf "$path"
        log_ok "Removed directory: $label"
    else
        log_skip "$label"
    fi
}

#######################################
# Discovery — find what's installed
#######################################

# Find all llm-cli managed GGUF model directories in HF cache
find_llm_models() {
    local models=()
    if [[ -d "$HF_CACHE_DIR" ]]; then
        for model_dir in "$HF_CACHE_DIR"/models--*; do
            [[ -d "$model_dir" ]] || continue
            # Check if this repo contains any GGUF files
            if find "$model_dir" -name "*.gguf" -print -quit 2>/dev/null | grep -q .; then
                models+=("$model_dir")
            fi
        done
    fi
    echo "${models[@]:-}"
}

#######################################
# Show summary of what will be removed
#######################################

show_summary() {
    echo ""
    echo -e "${BOLD}llm-cli Uninstaller${RESET}"
    echo "==================="
    echo ""
    echo "The following items will be removed:"
    echo ""

    # Binary / symlink
    local symlink="$INSTALL_PREFIX/llm-cli"
    if [[ -L "$symlink" ]] || [[ -e "$symlink" ]]; then
        echo -e "  ${CYAN}Binary:${RESET}       $symlink"
    fi

    # Source clone (curl-based install)
    local source_dir="$DATA_DIR/source"
    if [[ -d "$source_dir" ]]; then
        echo -e "  ${CYAN}Source:${RESET}       $source_dir"
    fi

    # Shell completions
    local has_completions=0
    if [[ -f "$BASH_COMP_DIR/llm-cli" ]]; then
        echo -e "  ${CYAN}Bash comp:${RESET}    $BASH_COMP_DIR/llm-cli"
        has_completions=1
    fi
    if [[ -f "$ZSH_COMP_DIR/_llm-cli" ]]; then
        echo -e "  ${CYAN}Zsh comp:${RESET}     $ZSH_COMP_DIR/_llm-cli"
        has_completions=1
    fi

    # Config
    if [[ $KEEP_CONFIG -eq 0 ]]; then
        if [[ -d "$CONFIG_DIR" ]]; then
            echo -e "  ${CYAN}Config:${RESET}       $CONFIG_DIR"
        fi
    else
        echo -e "  ${DIM}Config:       $CONFIG_DIR (kept)${RESET}"
    fi

    # Data (stats, sessions, benchmarks)
    if [[ -d "$DATA_DIR" ]]; then
        local data_size
        data_size=$(get_dir_size "$DATA_DIR")
        echo -e "  ${CYAN}Data:${RESET}         $DATA_DIR ($(format_size "$data_size"))"
    fi

    # Cache
    if [[ -d "$CACHE_DIR" ]]; then
        local cache_size
        cache_size=$(get_dir_size "$CACHE_DIR")
        echo -e "  ${CYAN}Cache:${RESET}        $CACHE_DIR ($(format_size "$cache_size"))"
    fi

    # Models
    if [[ $KEEP_MODELS -eq 0 ]]; then
        local model_dirs
        model_dirs=$(find_llm_models)
        if [[ -n "$model_dirs" ]]; then
            local total_model_size=0
            local model_count=0
            echo ""
            echo -e "  ${CYAN}Downloaded GGUF models:${RESET}"
            for model_dir in $model_dirs; do
                local repo_name
                repo_name=$(basename "$model_dir" | sed 's/^models--//' | sed 's/--/\//g')
                local model_size
                model_size=$(get_dir_size "$model_dir")
                total_model_size=$((total_model_size + model_size))
                model_count=$((model_count + 1))
                echo -e "    - $repo_name ($(format_size "$model_size"))"
            done
            echo ""
            echo -e "  ${YELLOW}Total model storage: $(format_size "$total_model_size") ($model_count model(s))${RESET}"
        fi
    else
        echo -e "  ${DIM}Models:       (kept)${RESET}"
    fi

    echo ""
}

#######################################
# Perform uninstallation
#######################################

do_uninstall() {
    echo ""
    log_info "Uninstalling llm-cli..."
    echo ""

    # 1. Remove binary symlink
    remove_item "$INSTALL_PREFIX/llm-cli" "$INSTALL_PREFIX/llm-cli"

    # 2. Remove shell completions
    remove_item "$BASH_COMP_DIR/llm-cli" "Bash completion"
    remove_item "$ZSH_COMP_DIR/_llm-cli" "Zsh completion"

    # 3. Remove config
    if [[ $KEEP_CONFIG -eq 0 ]]; then
        remove_item "$CONFIG_DIR" "Configuration ($CONFIG_DIR)"
    else
        log_info "Keeping configuration: $CONFIG_DIR"
    fi

    # 4. Remove cache
    remove_item "$CACHE_DIR" "Cache ($CACHE_DIR)"

    # 5. Remove downloaded GGUF models (with separate confirmation)
    if [[ $KEEP_MODELS -eq 0 ]]; then
        local model_dirs
        model_dirs=$(find_llm_models)
        if [[ -n "$model_dirs" ]]; then
            local total_model_size=0
            local model_count=0
            for model_dir in $model_dirs; do
                local ms
                ms=$(get_dir_size "$model_dir")
                total_model_size=$((total_model_size + ms))
                model_count=$((model_count + 1))
            done

            echo ""
            if confirm "Also remove $model_count downloaded model(s) ($(format_size "$total_model_size"))?"; then
                for model_dir in $model_dirs; do
                    local repo_name
                    repo_name=$(basename "$model_dir" | sed 's/^models--//' | sed 's/--/\//g')
                    remove_item "$model_dir" "Model: $repo_name"
                done
            else
                log_info "Keeping downloaded models in $HF_CACHE_DIR"
            fi
        fi
    else
        log_info "Keeping downloaded models in $HF_CACHE_DIR"
    fi

    # 6. Remove data directory (stats, sessions, benchmarks, source clone)
    # This is done last because it may contain the source clone
    remove_item "$DATA_DIR" "Data ($DATA_DIR)"

    echo ""
    log_ok "llm-cli has been uninstalled."
    echo ""

    # Remind about llama.cpp
    if command -v llama-cli &>/dev/null; then
        log_info "llama.cpp is still installed ($(command -v llama-cli))."
        echo "  To remove it:"
        if command -v brew &>/dev/null; then
            echo "    brew uninstall llama.cpp"
        else
            echo "    sudo rm -f /usr/local/bin/llama-*"
        fi
        echo ""
    fi

    # Remind about PATH entry
    echo -e "${DIM}If you added ~/.local/bin to your PATH for llm-cli, you may want to"
    echo -e "remove that line from your shell profile (~/.bashrc, ~/.zshrc, etc.).${RESET}"
    echo ""
}

#######################################
# Help
#######################################

show_help() {
    cat <<EOF
${BOLD}llm-cli Uninstall Script${RESET}

Usage: $0 [OPTIONS]

Options:
  --keep-models      Keep downloaded HuggingFace GGUF models
  --keep-config      Keep configuration files (~/.config/llm-cli)
  --yes              Skip confirmation prompts
  --help             Show this help

Examples:
  # Full uninstall (interactive)
  ./scripts/uninstall.sh

  # Uninstall but keep models (they can be large)
  ./scripts/uninstall.sh --keep-models

  # Uninstall keeping both config and models
  ./scripts/uninstall.sh --keep-config --keep-models

  # Non-interactive full removal
  ./scripts/uninstall.sh --yes

EOF
}

#######################################
# Main
#######################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --keep-models)
                KEEP_MODELS=1
                shift
                ;;
            --keep-config)
                KEEP_CONFIG=1
                shift
                ;;
            --yes | -y)
                AUTO_YES=1
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

    # Check if anything is installed
    local symlink="$INSTALL_PREFIX/llm-cli"
    if [[ ! -L "$symlink" ]] && [[ ! -e "$symlink" ]] && [[ ! -d "$DATA_DIR" ]] && [[ ! -d "$CONFIG_DIR" ]]; then
        log_warn "llm-cli does not appear to be installed."
        exit 0
    fi

    # Show what will be removed
    show_summary

    # Confirm
    if ! confirm "Proceed with uninstallation?"; then
        echo ""
        log_info "Uninstallation cancelled."
        exit 0
    fi

    do_uninstall
}

main "$@"
