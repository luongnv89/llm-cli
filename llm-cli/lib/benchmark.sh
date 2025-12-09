#!/bin/bash
# llm-cli: Benchmarking functions
# Run performance benchmarks on models

# Benchmark command dispatcher
cmd_bench() {
    local arg="$1"

    # Check dependencies
    check_dependencies

    if ! command -v llama-bench &>/dev/null; then
        die "llama-bench not found. Install with: brew install llama.cpp"
    fi

    case "$arg" in
        --all|-a)
            bench_all
            ;;
        --batch|-b)
            shift
            bench_batch "$@"
            ;;
        --help|-h)
            echo "Usage: llm-cli bench [options] [model_number]"
            echo ""
            echo "Options:"
            echo "  <N>              Benchmark model N"
            echo "  --all, -a        Benchmark all cached models"
            echo "  --batch 1,2,3    Benchmark specific models"
            echo "  --help, -h       Show this help"
            echo ""
            echo "Examples:"
            echo "  llm-cli bench        Interactive model selection"
            echo "  llm-cli bench 1      Benchmark first model"
            echo "  llm-cli bench --all  Benchmark all models"
            echo "  llm-cli bench --batch 1,3,5"
            ;;
        "")
            bench_single
            ;;
        *)
            bench_single "$arg"
            ;;
    esac
}

# Benchmark a single model
bench_single() {
    local model_num="$1"

    if ! scan_cached_models; then
        die "No cached models found"
    fi

    local count=${#MODEL_NAMES[@]}
    if [ $count -eq 0 ]; then
        die "No GGUF models found"
    fi

    local idx
    if [ -z "$model_num" ]; then
        # Interactive selection
        print_header "Select Model to Benchmark"
        echo ""
        for i in "${!MODEL_NAMES[@]}"; do
            echo -e "  ${CYAN}$((i+1)))${RESET} ${MODEL_NAMES[$i]} [${MODEL_SIZES[$i]}]"
        done
        echo ""

        read -rp "Select model (1-$count) or 'q' to quit: " selection

        [ "$selection" = "q" ] || [ "$selection" = "Q" ] && exit 0

        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $count ]; then
            die "Invalid selection: $selection"
        fi

        idx=$((selection - 1))
    else
        if ! [[ "$model_num" =~ ^[0-9]+$ ]] || [ "$model_num" -lt 1 ] || [ "$model_num" -gt $count ]; then
            die "Invalid model number: $model_num (available: 1-$count)"
        fi
        idx=$((model_num - 1))
    fi

    run_benchmark "$idx" 3
}

# Benchmark all cached models
bench_all() {
    if ! scan_cached_models; then
        die "No cached models found"
    fi

    local count=${#MODEL_NAMES[@]}
    if [ $count -eq 0 ]; then
        die "No GGUF models found"
    fi

    print_header "Benchmark All Models"
    echo ""
    echo "Found $count model(s) to benchmark"
    echo ""
    echo -e "${BOLD}Configuration:${RESET}"
    echo "  Threads:      $THREADS"
    echo "  GPU Layers:   $GPU_LAYERS"
    echo "  Prompt:       512 tokens"
    echo "  Generation:   128 tokens"
    echo "  Repetitions:  2"
    echo ""

    if ! confirm "Start benchmarking all models?"; then
        echo "Cancelled."
        exit 0
    fi

    echo ""
    print_line "=" 60

    local results=()

    for i in "${!MODEL_NAMES[@]}"; do
        local num=$((i + 1))
        echo ""
        echo -e "${BOLD}[$num/$count] ${MODEL_NAMES[$i]}${RESET}"
        print_line "-" 60

        local result
        result=$(run_benchmark_raw "$i" 2)

        # Store result for summary
        results+=("${MODEL_NAMES[$i]}|$result")

        echo ""
    done

    # Print summary
    print_line "=" 60
    echo ""
    print_header "Benchmark Summary"
    echo ""

    printf "%-50s %12s %12s\n" "Model" "Prompt (t/s)" "Gen (t/s)"
    print_line "-" 74
    for entry in "${results[@]}"; do
        local name="${entry%%|*}"
        local data="${entry#*|}"

        # Truncate name if too long
        if [ ${#name} -gt 48 ]; then
            name="${name:0:45}..."
        fi

        local pp tg
        pp=$(echo "$data" | grep -oE 'pp[^|]+\|[^t]+t/s' | head -1 | grep -oE '[0-9]+\.[0-9]+' || echo "N/A")
        tg=$(echo "$data" | grep -oE 'tg[^|]+\|[^t]+t/s' | head -1 | grep -oE '[0-9]+\.[0-9]+' || echo "N/A")

        printf "%-50s %12s %12s\n" "$name" "$pp" "$tg"
    done

    echo ""
    print_legend
}

# Benchmark specific models by number
bench_batch() {
    local batch_arg="$1"

    if [ -z "$batch_arg" ]; then
        echo "Usage: llm-cli bench --batch 1,2,3"
        exit 1
    fi

    if ! scan_cached_models; then
        die "No cached models found"
    fi

    local count=${#MODEL_NAMES[@]}

    # Parse comma-separated list
    IFS=',' read -ra model_nums <<< "$batch_arg"

    # Validate all numbers first
    for num in "${model_nums[@]}"; do
        if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt $count ]; then
            die "Invalid model number: $num (available: 1-$count)"
        fi
    done

    local batch_count=${#model_nums[@]}

    print_header "Batch Benchmark"
    echo ""
    echo "Benchmarking $batch_count model(s):"
    for num in "${model_nums[@]}"; do
        local idx=$((num - 1))
        echo "  - ${MODEL_NAMES[$idx]}"
    done
    echo ""

    if ! confirm "Start benchmarking?"; then
        echo "Cancelled."
        exit 0
    fi

    echo ""
    print_line "=" 60

    local i=1
    for num in "${model_nums[@]}"; do
        local idx=$((num - 1))
        echo ""
        echo -e "${BOLD}[$i/$batch_count] ${MODEL_NAMES[$idx]}${RESET}"
        print_line "-" 60

        run_benchmark "$idx" 2

        ((i++))
    done

    print_line "=" 60
    echo ""
    log_success "Batch benchmark complete!"
    print_legend
}

# Run benchmark and display results
run_benchmark() {
    local idx="$1"
    local reps="${2:-3}"

    local model_path="${MODEL_PATHS[$idx]}"
    local model_name="${MODEL_NAMES[$idx]}"

    echo ""
    echo -e "${BOLD}Model:${RESET} $model_name"
    echo ""

    llama-bench \
        -m "$model_path" \
        -t "$THREADS" \
        -ngl "$GPU_LAYERS" \
        -p 512 \
        -n 128 \
        -r "$reps" \
        --progress

    # Record benchmark in stats
    record_benchmark_result "$model_name"
}

# Run benchmark and return raw output (for parsing)
run_benchmark_raw() {
    local idx="$1"
    local reps="${2:-2}"

    local model_path="${MODEL_PATHS[$idx]}"

    llama-bench \
        -m "$model_path" \
        -t "$THREADS" \
        -ngl "$GPU_LAYERS" \
        -p 512 \
        -n 128 \
        -r "$reps" \
        2>/dev/null
}

# Print benchmark legend
print_legend() {
    echo ""
    echo -e "${BOLD}Legend:${RESET}"
    echo "  pp = Prompt Processing (tokens/sec) - How fast it processes input"
    echo "  tg = Text Generation (tokens/sec) - How fast it generates output"
}
