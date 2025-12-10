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

# Default configuration for M1 Max
# Can be overridden by config file or environment variables
DEFAULT_THREADS=8
DEFAULT_GPU_LAYERS=99
DEFAULT_CONTEXT_SIZE=4096
DEFAULT_SYSTEM_PROMPT="You are a helpful AI assistant. Answer safely and concisely."

# Quantization priority (for auto-selection)
readonly QUANT_PRIORITY=("Q5_K_M" "Q4_K_M" "Q6_K" "Q4_K_S" "Q8_0")

# Initialize directories
init_directories() {
    mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR"
}

# Create default config file if it doesn't exist
init_config() {
    init_directories

    if [ ! -f "$CONFIG_FILE" ]; then
        cat >"$CONFIG_FILE" <<'EOF'
# LLM CLI Configuration
# Edit this file to customize your settings

# Performance settings (optimized for M1 Max)
THREADS=8
GPU_LAYERS=99
CONTEXT_SIZE=4096

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
