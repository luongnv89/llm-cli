#!/bin/bash
# llm-cli: Chat/conversation functions
# Start conversations with models using llama-cli

# Chat command
cmd_chat() {
    local model_num="$1"

    # Check dependencies
    check_dependencies

    # Scan for models
    if ! scan_cached_models; then
        die "No HuggingFace cache found. Download a model first: llm-cli search <query>"
    fi

    local count=${#MODEL_NAMES[@]}
    if [ $count -eq 0 ]; then
        die "No GGUF models found. Download a model first: llm-cli search <query>"
    fi

    local idx
    local model_path
    local model_name

    if [ -z "$model_num" ]; then
        # Interactive selection
        print_header "Available Models"
        echo ""
        for i in "${!MODEL_NAMES[@]}"; do
            echo -e "  ${CYAN}$((i + 1)))${RESET} ${MODEL_NAMES[$i]} [${MODEL_SIZES[$i]}]"
        done
        echo ""

        read -rp "Select model (1-$count) or 'q' to quit: " selection

        [ "$selection" = "q" ] || [ "$selection" = "Q" ] && exit 0

        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $count ]; then
            die "Invalid selection: $selection"
        fi

        idx=$((selection - 1))
    else
        # Direct selection by number
        if ! [[ "$model_num" =~ ^[0-9]+$ ]] || [ "$model_num" -lt 1 ] || [ "$model_num" -gt $count ]; then
            die "Invalid model number: $model_num (available: 1-$count)"
        fi
        idx=$((model_num - 1))
    fi

    model_path="${MODEL_PATHS[$idx]}"
    model_name="${MODEL_NAMES[$idx]}"

    start_chat "$model_path" "$model_name"
}

# Start a chat session
start_chat() {
    local model_path="$1"
    local model_name="$2"

    echo ""
    echo -e "${BOLD}Model:${RESET}   $model_name"
    echo -e "${BOLD}Path:${RESET}    $model_path"
    echo ""
    echo -e "${BOLD}Configuration:${RESET}"
    echo "  Threads:      $THREADS"
    echo "  GPU Layers:   $GPU_LAYERS"
    echo "  Context Size: $CONTEXT_SIZE"
    echo ""
    print_line "-" 60
    echo -e "${BOLD}Starting conversation...${RESET}"
    echo -e "${DIM}(Type 'exit' or press Ctrl+C to quit)${RESET}"
    print_line "-" 60
    echo ""

    # Record session start time for stats
    local start_time
    start_time=$(date +%s)

    # Run llama-cli
    llama-cli \
        -m "$model_path" \
        -p "$SYSTEM_PROMPT" \
        -n 512 \
        -c "$CONTEXT_SIZE" \
        -t "$THREADS" \
        -ngl "$GPU_LAYERS" \
        --color \
        -cnv

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    print_line "-" 60
    log_info "Session ended. Duration: ${duration}s"

    # Record session in stats
    record_session "$model_name" "$duration"
}
