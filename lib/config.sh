#!/bin/bash
# llm-cli: Configuration management
# Handles XDG directories, config files, and default values

# Version
readonly LLM_CLI_VERSION="1.0.0"

# XDG Base Directory paths
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"

# Application directories
readonly CONFIG_DIR="${XDG_CONFIG_HOME}/llm-cli"
readonly DATA_DIR="${XDG_DATA_HOME}/llm-cli"
readonly CACHE_DIR="${XDG_CACHE_HOME}/llm-cli"

# Config and data files
readonly CONFIG_FILE="${CONFIG_DIR}/config"
readonly STATS_FILE="${DATA_DIR}/stats.json"
readonly SESSIONS_LOG="${DATA_DIR}/sessions.log"

# HuggingFace cache (standard location)
readonly HF_CACHE_DIR="${HF_HOME:-$HOME/.cache/huggingface}/hub"

# Platform detection
# Detects: macos, linux-nvidia, linux-cpu
# Can be overridden by --platform flag or LLM_CLI_PLATFORM env var
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

# Set platform (called after parsing --platform flag)
# Priority: --platform flag > LLM_CLI_PLATFORM env > auto-detect
set_platform() {
    local flag_platform="${1:-}"

    if [[ -n "$flag_platform" ]]; then
        # Validate flag value
        case "$flag_platform" in
            macos | linux-nvidia | linux-cpu)
                PLATFORM="$flag_platform"
                ;;
            *)
                echo "Warning: Invalid platform '$flag_platform'. Using auto-detection." >&2
                PLATFORM=$(detect_platform)
                ;;
        esac
    elif [[ -n "${LLM_CLI_PLATFORM:-}" ]]; then
        # Validate env value
        case "$LLM_CLI_PLATFORM" in
            macos | linux-nvidia | linux-cpu)
                PLATFORM="$LLM_CLI_PLATFORM"
                ;;
            *)
                echo "Warning: Invalid LLM_CLI_PLATFORM '$LLM_CLI_PLATFORM'. Using auto-detection." >&2
                PLATFORM=$(detect_platform)
                ;;
        esac
    else
        PLATFORM=$(detect_platform)
    fi

    export PLATFORM
}

# Get platform-specific defaults
get_platform_defaults() {
    case "$PLATFORM" in
        macos)
            DEFAULT_THREADS=8
            DEFAULT_GPU_LAYERS=99
            ;;
        linux-nvidia)
            # Optimized for DGX Spark: 10 P-cores across 2 clusters
            DEFAULT_THREADS=10
            DEFAULT_GPU_LAYERS=99
            ;;
        linux-cpu)
            # Use all available CPU cores, no GPU
            DEFAULT_THREADS=$(nproc 2>/dev/null || echo 4)
            DEFAULT_GPU_LAYERS=0
            ;;
    esac
}

# Default configuration (platform-neutral defaults, updated by set_platform)
DEFAULT_THREADS=8
DEFAULT_GPU_LAYERS=99
DEFAULT_CONTEXT_SIZE=4096
DEFAULT_SYSTEM_PROMPT="You are a helpful AI assistant. Answer safely and concisely."

# Initialize platform on first load (can be overridden later by set_platform)
PLATFORM=$(detect_platform)
get_platform_defaults

# Get quantization priority based on platform
# MXFP4 is optimized for NVIDIA Blackwell (DGX Spark) architecture
get_quant_priority() {
    case "${1:-$PLATFORM}" in
        linux-nvidia)
            # MXFP4 is specifically optimized for Blackwell architecture
            echo "MXFP4" "Q5_K_M" "Q4_K_M" "Q6_K" "Q4_K_S" "Q8_0"
            ;;
        *)
            # Standard priority for other platforms
            echo "Q5_K_M" "Q4_K_M" "Q6_K" "Q4_K_S" "Q8_0"
            ;;
    esac
}

# Set quantization priority at runtime
set_quant_priority() {
    local quant_list
    quant_list=$(get_quant_priority "$@")
    # Convert space-separated string to array (Bash 3.2 compatible)
    QUANT_PRIORITY=()
    for q in $quant_list; do
        QUANT_PRIORITY+=("$q")
    done
}

# Initialize directories
init_directories() {
    mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR"
}

# Create default config file if it doesn't exist
init_config() {
    init_directories

    if [ ! -f "$CONFIG_FILE" ]; then
        local platform_comment
        case "$PLATFORM" in
            macos)
                platform_comment="# Performance settings (optimized for Apple Silicon)"
                ;;
            linux-nvidia)
                platform_comment="# Performance settings (optimized for NVIDIA GPU / DGX Spark)"
                ;;
            linux-cpu)
                platform_comment="# Performance settings (CPU-only mode)"
                ;;
            *)
                platform_comment="# Performance settings"
                ;;
        esac

        cat >"$CONFIG_FILE" <<EOF
# LLM CLI Configuration
# Edit this file to customize your settings
# Detected platform: $PLATFORM

$platform_comment
THREADS=$DEFAULT_THREADS
GPU_LAYERS=$DEFAULT_GPU_LAYERS
CONTEXT_SIZE=$DEFAULT_CONTEXT_SIZE

# System prompt for chat sessions
SYSTEM_PROMPT="You are a helpful AI assistant. Answer safely and concisely."

# Output settings
# Set to 1 to disable colored output
NO_COLOR=0

# Verbosity: 0=quiet, 1=normal, 2=verbose
VERBOSE=1
EOF
    fi
}

# Load configuration
# Priority: Environment > Config File > Defaults
load_config() {
    # Start with defaults
    THREADS="$DEFAULT_THREADS"
    GPU_LAYERS="$DEFAULT_GPU_LAYERS"
    CONTEXT_SIZE="$DEFAULT_CONTEXT_SIZE"
    SYSTEM_PROMPT="$DEFAULT_SYSTEM_PROMPT"
    NO_COLOR=0
    VERBOSE=1

    # Load from config file if exists
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi

    # Environment variables override (LLM_CLI_ prefix)
    [ -n "${LLM_CLI_THREADS:-}" ] && THREADS="$LLM_CLI_THREADS"
    [ -n "${LLM_CLI_GPU_LAYERS:-}" ] && GPU_LAYERS="$LLM_CLI_GPU_LAYERS"
    [ -n "${LLM_CLI_CONTEXT_SIZE:-}" ] && CONTEXT_SIZE="$LLM_CLI_CONTEXT_SIZE"
    [ -n "${LLM_CLI_SYSTEM_PROMPT:-}" ] && SYSTEM_PROMPT="$LLM_CLI_SYSTEM_PROMPT"
    [ -n "${LLM_CLI_NO_COLOR:-}" ] && NO_COLOR="$LLM_CLI_NO_COLOR"
    [ -n "${LLM_CLI_VERBOSE:-}" ] && VERBOSE="$LLM_CLI_VERBOSE"

    # Also respect standard NO_COLOR env var
    [ -n "${NO_COLOR:-}" ] && NO_COLOR=1

    # Export for use in subprocesses
    export THREADS GPU_LAYERS CONTEXT_SIZE SYSTEM_PROMPT NO_COLOR VERBOSE
}

# Show current configuration
show_config() {
    echo "LLM CLI Configuration"
    echo "====================="
    echo ""
    echo "Platform:   $PLATFORM"
    echo ""
    echo "Directories:"
    echo "  Config:     $CONFIG_DIR"
    echo "  Data:       $DATA_DIR"
    echo "  Cache:      $CACHE_DIR"
    echo "  HF Cache:   $HF_CACHE_DIR"
    echo ""
    echo "Settings:"
    echo "  Threads:      $THREADS"
    echo "  GPU Layers:   $GPU_LAYERS"
    echo "  Context Size: $CONTEXT_SIZE"
    echo "  No Color:     $NO_COLOR"
    echo "  Verbose:      $VERBOSE"
    echo ""
    echo "Config file: $CONFIG_FILE"
}

# Open config file in editor
edit_config() {
    init_config
    local editor="${EDITOR:-${VISUAL:-nano}}"
    "$editor" "$CONFIG_FILE"
}
