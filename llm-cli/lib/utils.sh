#!/bin/bash
# llm-cli: Utility functions
# Logging, colors, error handling, prompts

# Color codes (disabled if NO_COLOR is set)
setup_colors() {
    if [ "${NO_COLOR:-0}" = "1" ] || [ ! -t 1 ]; then
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        CYAN=""
        BOLD=""
        DIM=""
        RESET=""
    else
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        BOLD='\033[1m'
        DIM='\033[2m'
        RESET='\033[0m'
    fi
}

# Logging functions
log_info() {
    [ "${VERBOSE:-1}" -ge 1 ] && echo -e "${BLUE}[INFO]${RESET} $*" >&2
}

log_success() {
    echo -e "${GREEN}[OK]${RESET} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $*" >&2
}

log_debug() {
    [ "${VERBOSE:-1}" -ge 2 ] && echo -e "${DIM}[DEBUG] $*${RESET}" >&2
}

# Exit with error message
die() {
    log_error "$1"
    exit "${2:-1}"
}

# Check if a command exists
require_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" &>/dev/null; then
        if [ -n "$install_hint" ]; then
            die "$cmd not found. Install with: $install_hint"
        else
            die "$cmd not found. Please install it first."
        fi
    fi
}

# Get platform-specific llama.cpp install hint
get_llama_install_hint() {
    case "$PLATFORM" in
        macos)
            echo "brew install llama.cpp"
            ;;
        linux-nvidia)
            echo "Build from source with CUDA: https://github.com/ggerganov/llama.cpp#cuda"
            ;;
        linux-cpu)
            echo "Build from source: https://github.com/ggerganov/llama.cpp#build"
            ;;
        *)
            echo "See https://github.com/ggerganov/llama.cpp"
            ;;
    esac
}

# Check required dependencies
check_dependencies() {
    local missing=()
    local install_hint

    if ! command -v llama-cli &>/dev/null; then
        install_hint=$(get_llama_install_hint)
        missing+=("llama-cli ($install_hint)")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required dependencies:"
        for dep in "${missing[@]}"; do
            echo "  - $dep" >&2
        done
        exit 1
    fi

    # Warn if NVIDIA GPU detected but CUDA may not be available in llama.cpp
    check_cuda_support
}

# Check CUDA support for NVIDIA platforms
check_cuda_support() {
    if [[ "$PLATFORM" == "linux-nvidia" ]]; then
        # Check if llama-cli was built with CUDA support
        # This is a heuristic check - llama-cli with CUDA typically shows CUDA in --help or uses GPU
        if command -v llama-cli &>/dev/null; then
            local llama_info
            llama_info=$(llama-cli --version 2>&1 || true)
            # Check for common CUDA-related strings in output
            if ! echo "$llama_info" | grep -qi -E "cuda|cublas|gpu" 2>/dev/null; then
                log_warn "NVIDIA GPU detected but llama.cpp may not have CUDA support."
                log_warn "For optimal performance, rebuild llama.cpp with CUDA:"
                log_warn "  cmake -B build -DGGML_CUDA=ON && cmake --build build"
            fi
        fi
    fi
}

# Get GPU memory in MB
get_gpu_memory_mb() {
    if [[ "$PLATFORM" != "linux-nvidia" ]] || ! command -v nvidia-smi &>/dev/null; then
        echo "0"
        return 1
    fi
    nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1 | sed 's/ MiB//'
}

# Show GPU memory and model recommendations for DGX Spark
show_gpu_memory_info() {
    if [[ "$PLATFORM" != "linux-nvidia" ]]; then
        return
    fi

    if ! command -v nvidia-smi &>/dev/null; then
        return
    fi

    local gpu_mem
    gpu_mem=$(get_gpu_memory_mb)

    if [[ -z "$gpu_mem" || "$gpu_mem" == "0" ]]; then
        return
    fi

    # Convert to GB for display
    local gpu_mem_gb=$((gpu_mem / 1024))

    echo ""
    echo -e "${BOLD}💾 GPU Memory Info:${RESET}"
    echo -e "${DIM}Total GPU Memory: ${gpu_mem_gb} GB${RESET}"
    echo ""
    echo -e "${DIM}Recommended model sizes:${RESET}"

    if [[ $gpu_mem_gb -ge 80 ]]; then
        # 80GB+ H200/H100
        echo -e "  • ${GREEN}70B models${RESET} (Q4_K_M, MXFP4) - ${DIM}Excellent fit${RESET}"
        echo -e "  • ${GREEN}20-30B models${RESET} (any quantization) - ${DIM}Optimal${RESET}"
        echo -e "  • ${GREEN}7-13B models${RESET} (Q8_0, full precision) - ${DIM}Full offload${RESET}"
    elif [[ $gpu_mem_gb -ge 40 ]]; then
        # 40GB L40S
        echo -e "  • ${GREEN}30B models${RESET} (Q4_K_M, MXFP4) - ${DIM}Good fit${RESET}"
        echo -e "  • ${GREEN}13B models${RESET} (Q8_0) - ${DIM}Recommended${RESET}"
        echo -e "  • ${YELLOW}7B models${RESET} (Q8_0, full) - ${DIM}Safer choice${RESET}"
    elif [[ $gpu_mem_gb -ge 24 ]]; then
        # 24GB (typical)
        echo -e "  • ${YELLOW}13B models${RESET} (Q4_K_M, MXFP4) - ${DIM}Recommended${RESET}"
        echo -e "  • ${GREEN}7B models${RESET} (Q8_0, full) - ${DIM}Best choice${RESET}"
        echo -e "  • ${YELLOW}3B models${RESET} (any quantization) - ${DIM}Safe option${RESET}"
    elif [[ $gpu_mem_gb -ge 12 ]]; then
        # 12GB (e.g., RTX 4080)
        echo -e "  • ${YELLOW}7B models${RESET} (Q4_K_M, MXFP4) - ${DIM}Try first${RESET}"
        echo -e "  • ${GREEN}3B models${RESET} (Q8_0, full) - ${DIM}Recommended${RESET}"
    else
        # <12GB
        echo -e "  • ${GREEN}3B models${RESET} (Q4_K_M) - ${DIM}Recommended${RESET}"
        echo -e "  • ${YELLOW}7B models${RESET} (Q2_K, Q3_K) - ${DIM}May work, reduce GPU_LAYERS${RESET}"
    fi

    echo ""
    echo -e "${DIM}Tip: Use MXFP4 quantization for better performance on Blackwell${RESET}"
    echo -e "${DIM}Adjust GPU_LAYERS with: LLM_CLI_GPU_LAYERS=50 llm-cli chat${RESET}"
    echo ""
}

# Check optional dependencies
check_optional_deps() {
    if ! command -v huggingface-cli &>/dev/null; then
        log_warn "huggingface-cli not found. Online features disabled."
        log_warn "Install with: pip install -U 'huggingface_hub[cli]'"
        return 1
    fi
    return 0
}

# Check if jq is available
has_jq() {
    command -v jq &>/dev/null
}

# Confirm action with user
confirm() {
    local message="${1:-Are you sure?}"
    local default="${2:-n}"

    local prompt
    if [ "$default" = "y" ]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    echo -en "${YELLOW}$message ${prompt}${RESET} " >&2
    read -r response

    # Convert to lowercase (compatible with Bash 3.2 on macOS)
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

    case "$response" in
        y | yes) return 0 ;;
        n | no) return 1 ;;
        "")
            [ "$default" = "y" ] && return 0 || return 1
            ;;
        *) return 1 ;;
    esac
}

# Interactive selection from list
# Usage: select_from_list "prompt" item1 item2 item3 ...
# Returns selected index (1-based) or 0 if cancelled
select_from_list() {
    local prompt="$1"
    shift
    local items=("$@")
    local count=${#items[@]}

    if [ $count -eq 0 ]; then
        log_error "No items to select from"
        return 0
    fi

    echo "" >&2
    local i=1
    for item in "${items[@]}"; do
        echo -e "  ${CYAN}$i)${RESET} $item" >&2
        ((i++))
    done
    echo "" >&2

    local choice
    read -rp "$prompt (1-$count) or 'q' to quit: " choice

    case "$choice" in
        q | Q)
            return 0
            ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
                echo "$choice"
                return 0
            else
                log_error "Invalid selection: $choice"
                return 1
            fi
            ;;
    esac
}

# Format bytes to human readable
format_size() {
    local bytes="$1"
    if [ "$bytes" -ge 1073741824 ]; then
        printf "%.1fG" "$(echo "scale=1; $bytes / 1073741824" | bc)"
    elif [ "$bytes" -ge 1048576 ]; then
        printf "%.1fM" "$(echo "scale=1; $bytes / 1048576" | bc)"
    elif [ "$bytes" -ge 1024 ]; then
        printf "%.1fK" "$(echo "scale=1; $bytes / 1024" | bc)"
    else
        printf "%dB" "$bytes"
    fi
}

# Get file size in human readable format
get_file_size() {
    local file="$1"
    if [ -f "$file" ]; then
        du -h "$file" 2>/dev/null | cut -f1
    else
        echo "N/A"
    fi
}

# Generate unique ID (simple implementation)
generate_id() {
    date +%s%N | sha256sum | head -c 8
}

# Get current timestamp in ISO format
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Print a horizontal line
print_line() {
    local char="${1:--}"
    local width="${2:-50}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

# Print header
print_header() {
    local title="$1"
    echo ""
    echo -e "${BOLD}$title${RESET}"
    print_line "=" "${#title}"
}

# Spinner for long operations
# Usage: long_command & spinner $! "Loading..."
spinner() {
    local pid=$1
    local message="${2:-Processing...}"
    local spin='|/-\'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${DIM}%s %c${RESET}" "$message" "${spin:i++%4:1}" >&2
        sleep 0.1
    done
    printf "\r%*s\r" $((${#message} + 3)) "" >&2
}

# Initialize colors on source
setup_colors
