#!/bin/bash
# llm-cli: Chat/conversation functions
# Start conversations with models using llama-cli

# Validate if input is a HuggingFace model ID
is_hf_model_id() {
    local input="$1"
    # HuggingFace model IDs contain "/" and are not purely numeric
    [[ "$input" == *"/"* ]]
}

# Chat command
cmd_chat() {
    local model_arg="$1"
    local prompt="$2"

    # Check dependencies
    check_dependencies

    # If argument provided and looks like HuggingFace model ID, use auto-download
    if [ -n "$model_arg" ] && is_hf_model_id "$model_arg"; then
        # HuggingFace model ID - auto-download via llama.cpp
        local model_path="hf://${model_arg}"
        start_chat "$model_path" "$model_arg" "$prompt"
        return
    fi

    # Scan for cached models
    if ! scan_cached_models; then
        log_info "No HuggingFace cache found."
        log_info ""
        log_info "You can:"
        log_info "  1. Download a model:     llm-cli search <query>"
        log_info "  2. Auto-download & chat: llm-cli chat <repo/model>"
        log_info ""
        log_info "Example:"
        log_info "  llm-cli chat bartowski/Llama-3.2-3B-GGUF"
        exit 1
    fi

    local count=${#MODEL_NAMES[@]}
    if [ $count -eq 0 ]; then
        log_info "No GGUF models found."
        log_info ""
        log_info "You can:"
        log_info "  1. Download a model:     llm-cli search <query>"
        log_info "  2. Auto-download & chat: llm-cli chat <repo/model>"
        log_info ""
        log_info "Example:"
        log_info "  llm-cli chat bartowski/Llama-3.2-3B-GGUF"
        exit 1
    fi

    local idx
    local model_path
    local model_name

    if [ -z "$model_arg" ]; then
        # Interactive selection
        print_header "Available Models"
        echo ""
        for i in "${!MODEL_NAMES[@]}"; do
            echo -e "  ${CYAN}$((i + 1)))${RESET} ${MODEL_NAMES[$i]} [${MODEL_SIZES[$i]}]"
        done
        echo ""
        echo -e "${DIM}Tip: You can also use HuggingFace model IDs directly:${RESET}"
        echo -e "  ${DIM}llm-cli chat bartowski/Llama-3.2-3B-GGUF${RESET}"
        echo ""

        read -rp "Select model (1-$count) or 'q' to quit: " selection

        [ "$selection" = "q" ] || [ "$selection" = "Q" ] && exit 0

        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $count ]; then
            die "Invalid selection: $selection"
        fi

        idx=$((selection - 1))
    else
        # Direct selection by number
        if ! [[ "$model_arg" =~ ^[0-9]+$ ]] || [ "$model_arg" -lt 1 ] || [ "$model_arg" -gt $count ]; then
            die "Invalid model number: $model_arg (available: 1-$count)"
        fi
        idx=$((model_arg - 1))
    fi

    model_path="${MODEL_PATHS[$idx]}"
    model_name="${MODEL_NAMES[$idx]}"

    start_chat "$model_path" "$model_name" "$prompt"
}

# Start a chat session
start_chat() {
    local model_path="$1"
    local model_name="$2"
    local prompt="$3"

    echo ""
    echo -e "${BOLD}Model:${RESET}   $model_name"
    echo -e "${BOLD}Path:${RESET}    $model_path"
    echo ""

    # Show GPU memory info on NVIDIA systems (with recommendations)
    show_gpu_memory_info

    echo -e "${BOLD}Configuration:${RESET}"
    echo "  Threads:      $THREADS"
    echo "  GPU Layers:   $GPU_LAYERS"
    echo "  Context Size: $CONTEXT_SIZE"
    echo ""
    print_line "-" 60
    echo -e "${BOLD}Starting conversation...${RESET}"
    if [ -z "$prompt" ]; then
        echo -e "${DIM}(Type 'exit' or press Ctrl+C to quit)${RESET}"
    fi
    print_line "-" 60
    echo ""

    # Record session start time for stats
    local start_time
    start_time=$(date +%s)

    # Run llama-cli
    if [ -n "$prompt" ]; then
        # Non-interactive mode with initial prompt
        llama-cli \
            -m "$model_path" \
            -p "$SYSTEM_PROMPT" \
            -n 512 \
            -c "$CONTEXT_SIZE" \
            -t "$THREADS" \
            -ngl "$GPU_LAYERS" \
            --color \
            <<<"$prompt"
    else
        # Interactive mode
        llama-cli \
            -m "$model_path" \
            -p "$SYSTEM_PROMPT" \
            -n 512 \
            -c "$CONTEXT_SIZE" \
            -t "$THREADS" \
            -ngl "$GPU_LAYERS" \
            --color \
            -cnv
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    print_line "-" 60
    log_info "Session ended. Duration: ${duration}s"

    # Record session in stats
    record_session "$model_name" "$duration"
}
