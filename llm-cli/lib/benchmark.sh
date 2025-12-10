#!/bin/bash
# llm-cli: Benchmarking functions
# Run performance benchmarks on models

# Benchmark reports directory (can be overridden by --output)
BENCH_REPORTS_DIR="${DATA_DIR}/benchmarks"
BENCH_OUTPUT_DIR="" # Custom output directory if specified

# Get the effective reports directory
get_reports_dir() {
    if [ -n "$BENCH_OUTPUT_DIR" ]; then
        echo "$BENCH_OUTPUT_DIR"
    else
        echo "$BENCH_REPORTS_DIR"
    fi
}

# Initialize benchmark reports directory
init_bench_reports() {
    local dir
    dir=$(get_reports_dir)
    mkdir -p "$dir"
}

# Generate report filename
# Format: benchmark_<model-short-name>_<date>_<time>.md
generate_report_filename() {
    local model_name="$1"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")

    # Extract short model name (last part of repo/model, sanitized)
    local short_name
    short_name=$(echo "$model_name" | sed 's|.*/||' | sed 's|[^a-zA-Z0-9._-]|_|g' | cut -c1-40)

    echo "benchmark_${short_name}_${timestamp}.md"
}

# Get system info for report
get_system_info() {
    echo "## System Information"
    echo ""
    echo "- **Date**: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "- **Host**: $(hostname)"
    echo "- **OS**: $(uname -s) $(uname -r)"
    if [ "$(uname -s)" = "Darwin" ]; then
        echo "- **Chip**: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Unknown')"
        echo "- **Memory**: $(($(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 / 1024)) GB"
    fi
    # Get llama.cpp version
    local llama_version
    llama_version=$(llama-cli --version 2>&1 | grep -oE 'version: [0-9]+ \([a-f0-9]+\)' | head -1 || echo 'Unknown')
    echo "- **llama.cpp version**: $llama_version"
    echo ""
}

# List saved benchmark reports
list_benchmark_reports() {
    init_bench_reports

    local reports_dir
    reports_dir=$(get_reports_dir)
    local reports
    reports=$(ls -1t "$reports_dir"/*.md 2>/dev/null || true)

    if [ -z "$reports" ]; then
        log_info "No benchmark reports found."
        echo ""
        echo "Run a benchmark to generate a report:"
        echo "  llm-cli bench"
        echo ""
        echo "Reports location: $reports_dir"
        return 0
    fi

    print_header "Saved Benchmark Reports"
    echo ""
    echo "Location: $reports_dir"
    echo ""

    local i=1
    declare -a REPORT_FILES

    while IFS= read -r report; do
        [ -z "$report" ] && continue
        REPORT_FILES[$i]="$report"

        local filename
        filename=$(basename "$report")

        # Extract info from filename
        local size
        size=$(du -h "$report" | cut -f1)

        echo -e "  ${CYAN}$i)${RESET} $filename ${DIM}[$size]${RESET}"
        ((i++))
    done <<<"$reports"

    local count=$((i - 1))
    echo ""
    read -rp "View report (1-$count) or 'q' to quit: " choice

    [ "$choice" = "q" ] || [ "$choice" = "Q" ] && return 0

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $count ]; then
        die "Invalid selection: $choice"
    fi

    local selected_report="${REPORT_FILES[$choice]}"
    echo ""
    print_line "=" 60

    # Display report with less or cat
    if command -v less &>/dev/null; then
        less "$selected_report"
    else
        cat "$selected_report"
    fi
}

# Benchmark command dispatcher
cmd_bench() {
    local args=("$@")
    local action=""
    local model_num=""
    local batch_arg=""

    # Check dependencies
    check_dependencies

    if ! command -v llama-bench &>/dev/null; then
        die "llama-bench not found. Install with: brew install llama.cpp"
    fi

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --output | -o)
                shift
                if [ -z "${1:-}" ]; then
                    die "Missing path for --output option"
                fi
                BENCH_OUTPUT_DIR="$1"
                # Validate the path
                if [ ! -d "$BENCH_OUTPUT_DIR" ]; then
                    mkdir -p "$BENCH_OUTPUT_DIR" || die "Cannot create output directory: $BENCH_OUTPUT_DIR"
                fi
                shift
                ;;
            --all | -a)
                action="all"
                shift
                ;;
            --batch | -b)
                action="batch"
                shift
                batch_arg="${1:-}"
                [ -n "$batch_arg" ] && shift
                ;;
            --reports | -r)
                action="reports"
                shift
                ;;
            --help | -h)
                action="help"
                shift
                ;;
            -*)
                die "Unknown option: $1"
                ;;
            *)
                model_num="$1"
                shift
                ;;
        esac
    done

    # Execute action
    case "$action" in
        all)
            bench_all
            ;;
        batch)
            bench_batch "$batch_arg"
            ;;
        reports)
            list_benchmark_reports
            ;;
        help)
            echo "Usage: llm-cli bench [options] [model_number]"
            echo ""
            echo "Options:"
            echo "  <N>              Benchmark model N"
            echo "  --all, -a        Benchmark all cached models"
            echo "  --batch 1,2,3    Benchmark specific models"
            echo "  --output, -o     Specify output directory for reports"
            echo "  --reports, -r    List saved benchmark reports"
            echo "  --help, -h       Show this help"
            echo ""
            echo "Examples:"
            echo "  llm-cli bench              Interactive model selection"
            echo "  llm-cli bench 1            Benchmark first model"
            echo "  llm-cli bench --all        Benchmark all models"
            echo "  llm-cli bench --batch 1,3,5"
            echo "  llm-cli bench --reports    View saved reports"
            echo "  llm-cli bench -o ./reports Benchmark and save to ./reports/"
            echo "  llm-cli bench --all -o /tmp/bench"
            echo ""
            echo "Default reports location: ${DATA_DIR}/benchmarks/"
            ;;
        *)
            bench_single "$model_num"
            ;;
    esac
}

# Benchmark a single model
bench_single() {
    local model_num="${1:-}"

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
    local raw_outputs=()

    for i in "${!MODEL_NAMES[@]}"; do
        local num=$((i + 1))
        echo ""
        echo -e "${BOLD}[$num/$count] ${MODEL_NAMES[$i]}${RESET}"
        print_line "-" 60

        local result
        result=$(run_benchmark_raw "$i" 2 | tee /dev/stderr)

        # Store result for summary
        results+=("${MODEL_NAMES[$i]}|${MODEL_SIZES[$i]}|$result")

        echo ""
    done

    # Print summary
    print_line "=" 60
    echo ""
    print_header "Benchmark Summary"
    echo ""

    printf "%-50s %12s %12s\n" "Model" "Prompt (t/s)" "Gen (t/s)"
    print_line "-" 74

    # Prepare summary data for report
    local summary_lines=()

    for entry in "${results[@]}"; do
        local name size data
        name="${entry%%|*}"
        local rest="${entry#*|}"
        size="${rest%%|*}"
        data="${rest#*|}"

        # Truncate name if too long for display
        local display_name="$name"
        if [ ${#display_name} -gt 48 ]; then
            display_name="${display_name:0:45}..."
        fi

        local pp tg
        pp=$(echo "$data" | grep -oE 'pp[^|]+\|[^t]+t/s' | head -1 | grep -oE '[0-9]+\.[0-9]+' || echo "N/A")
        tg=$(echo "$data" | grep -oE 'tg[^|]+\|[^t]+t/s' | head -1 | grep -oE '[0-9]+\.[0-9]+' || echo "N/A")

        printf "%-50s %12s %12s\n" "$display_name" "$pp" "$tg"

        # Store for report
        summary_lines+=("$name|$size|$pp|$tg")
    done

    echo ""
    print_legend

    # Save combined report
    save_all_benchmark_report "${summary_lines[@]}"
}

# Save combined benchmark report for all models
save_all_benchmark_report() {
    local summary_lines=("$@")

    init_bench_reports

    local reports_dir
    reports_dir=$(get_reports_dir)
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local report_file="${reports_dir}/benchmark_all_models_${timestamp}.md"

    {
        echo "# Benchmark Report - All Models"
        echo ""
        get_system_info
        echo "## Benchmark Configuration"
        echo ""
        echo "- **Threads**: $THREADS"
        echo "- **GPU Layers**: $GPU_LAYERS"
        echo "- **Prompt Tokens**: 512"
        echo "- **Generation Tokens**: 128"
        echo "- **Repetitions**: 2"
        echo ""
        echo "## Results Summary"
        echo ""
        echo "| Model | Size | Prompt (t/s) | Generation (t/s) |"
        echo "|-------|------|--------------|------------------|"

        for line in "${summary_lines[@]}"; do
            local name size pp tg
            name="${line%%|*}"
            local rest="${line#*|}"
            size="${rest%%|*}"
            rest="${rest#*|}"
            pp="${rest%%|*}"
            tg="${rest#*|}"

            echo "| $name | $size | $pp | $tg |"
        done

        echo ""
        echo "## Legend"
        echo ""
        echo "- **pp (Prompt Processing)**: How fast the model processes input tokens (higher is better)"
        echo "- **tg (Text Generation)**: How fast the model generates output tokens (higher is better)"
        echo ""
        echo "---"
        echo "*Generated by llm-cli v${LLM_CLI_VERSION}*"
    } >"$report_file"

    echo ""
    log_success "Report saved: $report_file"
}

# Benchmark specific models by number
bench_batch() {
    local batch_arg="${1:-}"

    if [ -z "$batch_arg" ]; then
        echo "Usage: llm-cli bench --batch 1,2,3"
        exit 1
    fi

    if ! scan_cached_models; then
        die "No cached models found"
    fi

    local count=${#MODEL_NAMES[@]}

    # Parse comma-separated list
    IFS=',' read -ra model_nums <<<"$batch_arg"

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

    local results=()
    local i=1
    for num in "${model_nums[@]}"; do
        local idx=$((num - 1))
        echo ""
        echo -e "${BOLD}[$i/$batch_count] ${MODEL_NAMES[$idx]}${RESET}"
        print_line "-" 60

        local result
        result=$(run_benchmark_raw "$idx" 2 | tee /dev/stderr)

        # Extract metrics
        local pp tg
        pp=$(echo "$result" | grep -oE 'pp[^|]+\|[^t]+t/s' | head -1 | grep -oE '[0-9]+\.[0-9]+' || echo "N/A")
        tg=$(echo "$result" | grep -oE 'tg[^|]+\|[^t]+t/s' | head -1 | grep -oE '[0-9]+\.[0-9]+' || echo "N/A")

        results+=("${MODEL_NAMES[$idx]}|${MODEL_SIZES[$idx]}|$pp|$tg")

        ((i++))
    done

    print_line "=" 60
    echo ""
    log_success "Batch benchmark complete!"
    print_legend

    # Save batch report first
    save_batch_benchmark_report "$batch_arg" "${results[@]}"

    # Record in stats (non-fatal if fails)
    for num in "${model_nums[@]}"; do
        local idx=$((num - 1))
        record_benchmark_result "${MODEL_NAMES[$idx]}" || true
    done
}

# Save batch benchmark report
save_batch_benchmark_report() {
    local batch_arg="$1"
    shift
    local results=("$@")

    init_bench_reports

    local reports_dir
    reports_dir=$(get_reports_dir)
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local report_file="${reports_dir}/benchmark_batch_${batch_arg}_${timestamp}.md"

    {
        echo "# Benchmark Report - Batch ($batch_arg)"
        echo ""
        get_system_info
        echo "## Benchmark Configuration"
        echo ""
        echo "- **Threads**: $THREADS"
        echo "- **GPU Layers**: $GPU_LAYERS"
        echo "- **Prompt Tokens**: 512"
        echo "- **Generation Tokens**: 128"
        echo "- **Repetitions**: 2"
        echo ""
        echo "## Results Summary"
        echo ""
        echo "| Model | Size | Prompt (t/s) | Generation (t/s) |"
        echo "|-------|------|--------------|------------------|"

        for line in "${results[@]}"; do
            local name size pp tg
            name="${line%%|*}"
            local rest="${line#*|}"
            size="${rest%%|*}"
            rest="${rest#*|}"
            pp="${rest%%|*}"
            tg="${rest#*|}"

            echo "| $name | $size | $pp | $tg |"
        done

        echo ""
        echo "## Legend"
        echo ""
        echo "- **pp (Prompt Processing)**: How fast the model processes input tokens (higher is better)"
        echo "- **tg (Text Generation)**: How fast the model generates output tokens (higher is better)"
        echo ""
        echo "---"
        echo "*Generated by llm-cli v${LLM_CLI_VERSION}*"
    } >"$report_file"

    echo ""
    log_success "Report saved: $report_file"
}

# Run benchmark and display results
run_benchmark() {
    local idx="$1"
    local reps="${2:-3}"
    local save_report="${3:-true}"

    local model_path="${MODEL_PATHS[$idx]}"
    local model_name="${MODEL_NAMES[$idx]}"
    local model_size="${MODEL_SIZES[$idx]}"

    echo ""
    echo -e "${BOLD}Model:${RESET} $model_name"
    echo ""

    # Create a temp file to capture output
    local tmp_output
    tmp_output=$(mktemp)

    # Run benchmark, capture stdout to file while displaying to user
    # llama-bench outputs results to stdout (markdown by default)
    # and progress/diagnostics to stderr
    llama-bench \
        -m "$model_path" \
        -t "$THREADS" \
        -ngl "$GPU_LAYERS" \
        -p 512 \
        -n 128 \
        -r "$reps" \
        --progress 2>&1 | tee "$tmp_output"

    # Read captured output
    local bench_output
    bench_output=$(cat "$tmp_output")
    rm -f "$tmp_output"

    # Save report first (before stats, in case stats fails)
    if [ "$save_report" = "true" ]; then
        save_benchmark_report "$model_name" "$model_path" "$model_size" "$bench_output" "$reps"
    fi

    # Record benchmark in stats (non-fatal if fails)
    record_benchmark_result "$model_name" || true
}

# Save benchmark report to file
save_benchmark_report() {
    local model_name="$1"
    local model_path="$2"
    local model_size="$3"
    local bench_output="$4"
    local reps="$5"

    init_bench_reports

    local reports_dir
    reports_dir=$(get_reports_dir)
    local report_file
    report_file="${reports_dir}/$(generate_report_filename "$model_name")"

    # Extract performance metrics from output
    # Format: | model | size | params | backend | threads | test | t/s |
    # e.g., | llama 1B Q8_0 | 1.22 GiB | 1.24 B | Metal,BLAS | 8 | pp512 | 3591.88 ± 6.30 |
    local pp_speed tg_speed
    pp_speed=$(echo "$bench_output" | grep -E '\|\s*pp[0-9]+\s*\|' | grep -oE '[0-9]+\.[0-9]+\s*±' | head -1 | grep -oE '[0-9]+\.[0-9]+' || echo "N/A")
    tg_speed=$(echo "$bench_output" | grep -E '\|\s*tg[0-9]+\s*\|' | grep -oE '[0-9]+\.[0-9]+\s*±' | head -1 | grep -oE '[0-9]+\.[0-9]+' || echo "N/A")

    # Generate report
    {
        echo "# Benchmark Report"
        echo ""
        echo "## Model"
        echo ""
        echo "- **Name**: $model_name"
        echo "- **Path**: $model_path"
        echo "- **Size**: $model_size"
        echo ""
        get_system_info
        echo "## Benchmark Configuration"
        echo ""
        echo "- **Threads**: $THREADS"
        echo "- **GPU Layers**: $GPU_LAYERS"
        echo "- **Prompt Tokens**: 512"
        echo "- **Generation Tokens**: 128"
        echo "- **Repetitions**: $reps"
        echo ""
        echo "## Results"
        echo ""
        echo "| Metric | Value |"
        echo "|--------|-------|"
        echo "| Prompt Processing (pp) | $pp_speed t/s |"
        echo "| Text Generation (tg) | $tg_speed t/s |"
        echo ""
        echo "## Raw Output"
        echo ""
        echo '```'
        echo "$bench_output"
        echo '```'
        echo ""
        echo "---"
        echo "*Generated by llm-cli v${LLM_CLI_VERSION}*"
    } >"$report_file"

    echo ""
    log_success "Report saved: $report_file"
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
