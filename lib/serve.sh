#!/bin/bash
# llm-cli: Server management functions
# Start and manage llama-server for OpenAI-compatible API

# Server state files
readonly SERVER_PID_FILE="${DATA_DIR}/server.pid"
readonly SERVER_LOG_FILE="${DATA_DIR}/server.log"

# Default server configuration
readonly DEFAULT_SERVER_PORT=8000
readonly DEFAULT_SERVER_HOST="127.0.0.1"
readonly DEFAULT_SERVER_PARALLEL=1

# Check if llama-server is available
check_server_binary() {
    if ! command -v llama-server &>/dev/null; then
        local install_hint
        install_hint=$(get_llama_install_hint)
        log_error "llama-server not found."
        echo "" >&2
        echo "llama-server is required to run the API server." >&2
        echo "Install with: $install_hint" >&2
        return 1
    fi
    return 0
}

# Check if a port is available
check_port_available() {
    local port="$1"

    if command -v lsof &>/dev/null; then
        if lsof -i ":$port" &>/dev/null; then
            return 1
        fi
    elif command -v nc &>/dev/null; then
        if nc -z localhost "$port" 2>/dev/null; then
            return 1
        fi
    fi
    # Assume available if we can't check
    return 0
}

# Get the process using a port
get_port_process() {
    local port="$1"

    if command -v lsof &>/dev/null; then
        lsof -i ":$port" -t 2>/dev/null | head -1
    else
        echo ""
    fi
}

# Resolve model for serve command
# Accepts: number (1-based index), HuggingFace ID, or file path
resolve_model_for_serve() {
    local model_arg="$1"

    # If empty, show interactive selection
    if [[ -z "$model_arg" ]]; then
        if ! scan_cached_models; then
            log_error "No cached models found."
            echo "Download a model first: llm-cli search <query>" >&2
            return 1
        fi

        local count=${#MODEL_NAMES[@]}
        if [[ $count -eq 0 ]]; then
            log_error "No GGUF models found in cache."
            return 1
        fi

        print_header "Available Models"
        echo ""
        for i in "${!MODEL_NAMES[@]}"; do
            echo -e "  ${CYAN}$((i + 1)))${RESET} ${MODEL_NAMES[$i]} [${MODEL_SIZES[$i]}]"
        done
        echo ""

        local selection
        read -rp "Select model (1-$count) or 'q' to quit: " selection

        [[ "$selection" == "q" || "$selection" == "Q" ]] && return 1

        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt $count ]]; then
            log_error "Invalid selection: $selection"
            return 1
        fi

        local idx=$((selection - 1))
        SERVE_MODEL_PATH="${MODEL_PATHS[$idx]}"
        SERVE_MODEL_NAME="${MODEL_NAMES[$idx]}"
        return 0
    fi

    # If numeric, treat as model index
    if [[ "$model_arg" =~ ^[0-9]+$ ]]; then
        if ! scan_cached_models; then
            log_error "No cached models found."
            return 1
        fi

        local count=${#MODEL_NAMES[@]}
        if [[ "$model_arg" -lt 1 ]] || [[ "$model_arg" -gt $count ]]; then
            log_error "Invalid model number: $model_arg (available: 1-$count)"
            return 1
        fi

        local idx=$((model_arg - 1))
        SERVE_MODEL_PATH="${MODEL_PATHS[$idx]}"
        SERVE_MODEL_NAME="${MODEL_NAMES[$idx]}"
        return 0
    fi

    # If it's a file path
    if [[ -f "$model_arg" ]]; then
        SERVE_MODEL_PATH="$model_arg"
        SERVE_MODEL_NAME="$(basename "$model_arg")"
        return 0
    fi

    # If it looks like a HuggingFace model ID
    if is_hf_model_id "$model_arg"; then
        SERVE_MODEL_PATH="hf://${model_arg}"
        SERVE_MODEL_NAME="$model_arg"
        return 0
    fi

    log_error "Cannot find model: $model_arg"
    echo "Provide a model number, file path, or HuggingFace ID." >&2
    return 1
}

# Wait for server to be ready
wait_for_server_ready() {
    local endpoint="$1"
    local timeout="${2:-30}"
    local elapsed=0

    echo -n "Waiting for server to be ready" >&2
    while [[ $elapsed -lt $timeout ]]; do
        if curl -s -m 2 "${endpoint}/v1/models" >/dev/null 2>&1; then
            echo "" >&2
            return 0
        fi
        echo -n "." >&2
        sleep 1
        ((elapsed++))
    done

    echo "" >&2
    return 1
}

# Display server configuration before starting
display_serve_config() {
    local model_name="$1"
    local model_path="$2"
    local host="$3"
    local port="$4"
    local context="$5"
    local threads="$6"
    local gpu_layers="$7"
    local parallel="$8"
    local api_key="$9"

    echo ""
    echo -e "${BOLD}Server Configuration${RESET}"
    print_line "=" 40
    echo ""
    echo -e "${BOLD}Model:${RESET}       $model_name"
    echo -e "${BOLD}Path:${RESET}        $model_path"
    echo ""
    echo -e "${BOLD}Network:${RESET}"
    echo "  Host:      $host"
    echo "  Port:      $port"
    echo "  Endpoint:  http://${host}:${port}"
    echo ""
    echo -e "${BOLD}Performance:${RESET}"
    echo "  Threads:      $threads"
    echo "  GPU Layers:   $gpu_layers"
    echo "  Context Size: $context"
    echo "  Parallel:     $parallel"
    echo ""
    if [[ -n "$api_key" ]]; then
        echo -e "${BOLD}Security:${RESET}"
        echo "  API Key:   (set)"
        echo ""
    fi
}

# Display usage guide after server starts
# Shows how to use the server as an OpenAI-compatible endpoint
render_serve_usage_guide() {
    local endpoint="$1"
    local model_name="$2"
    local api_key="$3"
    local mode="$4" # "foreground" or "background"

    local api_key_value
    if [[ -n "$api_key" ]]; then
        api_key_value="$api_key"
    else
        api_key_value="sk-local"
    fi

    # For background mode, try to get the actual model ID from the running server
    local model_id="$model_name"
    if [[ "$mode" == "background" ]]; then
        local fetched_model
        fetched_model=$(get_available_models "$endpoint" 2 | head -1)
        if [[ -n "$fetched_model" ]]; then
            model_id="$fetched_model"
        fi
    fi

    echo ""
    print_line "=" 60
    echo -e "${BOLD}  Usage Guide — OpenAI-Compatible API${RESET}"
    print_line "=" 60
    echo ""
    echo -e "  ${BOLD}Base URL:${RESET}  ${CYAN}${endpoint}/v1${RESET}"
    echo -e "  ${BOLD}API Key:${RESET}   ${api_key_value}"
    echo -e "  ${BOLD}Model:${RESET}     ${model_id}"
    echo ""

    # Quick test with curl
    echo -e "${BOLD}Quick Test:${RESET}"
    echo ""
    if [[ -n "$api_key" ]]; then
        cat <<EOF
  curl -s ${endpoint}/v1/chat/completions \\
    -H "Content-Type: application/json" \\
    -H "Authorization: Bearer ${api_key_value}" \\
    -d '{
      "model": "${model_id}",
      "messages": [{"role": "user", "content": "Hello!"}]
    }'
EOF
    else
        cat <<EOF
  curl -s ${endpoint}/v1/chat/completions \\
    -H "Content-Type: application/json" \\
    -d '{
      "model": "${model_id}",
      "messages": [{"role": "user", "content": "Hello!"}]
    }'
EOF
    fi

    # Python example
    echo ""
    echo -e "${BOLD}Python (openai SDK):${RESET}"
    cat <<EOF

  from openai import OpenAI
  client = OpenAI(base_url="${endpoint}/v1", api_key="${api_key_value}")
  r = client.chat.completions.create(
      model="${model_id}",
      messages=[{"role": "user", "content": "Hello!"}],
  )
  print(r.choices[0].message.content)
EOF

    echo ""
    echo -e "${DIM}Run 'llm-cli info --format examples' for more examples (Node.js, cURL).${RESET}"
    echo ""
}

# Build llama-server command arguments
build_server_args() {
    local model_path="$1"
    local host="$2"
    local port="$3"
    local context="$4"
    local threads="$5"
    local gpu_layers="$6"
    local parallel="$7"
    local api_key="$8"

    local args=()
    args+=("-m" "$model_path")
    args+=("--host" "$host")
    args+=("--port" "$port")
    args+=("-c" "$context")
    args+=("-t" "$threads")
    args+=("-ngl" "$gpu_layers")
    args+=("-np" "$parallel")
    args+=("--metrics")

    if [[ -n "$api_key" ]]; then
        args+=("--api-key" "$api_key")
    fi

    echo "${args[@]}"
}

# Start server in foreground mode
start_server_foreground() {
    local model_path="$1"
    local host="$2"
    local port="$3"
    local context="$4"
    local threads="$5"
    local gpu_layers="$6"
    local parallel="$7"
    local api_key="$8"

    # Show usage guide before server takes over the terminal
    local endpoint="http://${host}:${port}"
    render_serve_usage_guide "$endpoint" "$SERVE_MODEL_NAME" "$api_key" "foreground"

    print_line "-" 60
    echo -e "${BOLD}Starting llama-server...${RESET}"
    echo -e "${DIM}(Press Ctrl+C to stop)${RESET}"
    print_line "-" 60
    echo ""

    # Build command arguments
    local args
    args=$(build_server_args "$model_path" "$host" "$port" "$context" "$threads" "$gpu_layers" "$parallel" "$api_key")

    # Set up signal handlers
    trap 'echo ""; log_info "Shutting down server..."; exit 0' INT TERM

    # Run the server
    # shellcheck disable=SC2086
    llama-server $args
}

# Start server in background mode
start_server_background() {
    local model_path="$1"
    local host="$2"
    local port="$3"
    local context="$4"
    local threads="$5"
    local gpu_layers="$6"
    local parallel="$7"
    local api_key="$8"

    # Ensure data directory exists
    mkdir -p "$DATA_DIR"

    # Check if already running
    if [[ -f "$SERVER_PID_FILE" ]]; then
        local pid
        pid=$(cat "$SERVER_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_error "Server already running (PID: $pid)"
            echo "Use 'llm-cli serve --stop' to stop it first." >&2
            return 1
        else
            # Stale PID file
            rm -f "$SERVER_PID_FILE"
        fi
    fi

    log_info "Starting server in background..."

    # Build command arguments
    local args
    args=$(build_server_args "$model_path" "$host" "$port" "$context" "$threads" "$gpu_layers" "$parallel" "$api_key")

    # Start server in background
    # shellcheck disable=SC2086
    nohup llama-server $args >"$SERVER_LOG_FILE" 2>&1 &
    local pid=$!

    # Save PID
    echo "$pid" >"$SERVER_PID_FILE"

    # Wait for server to start
    local endpoint="http://${host}:${port}"
    if wait_for_server_ready "$endpoint" 30; then
        log_success "Server started successfully (PID: $pid)"
        echo ""
        echo -e "${BOLD}Endpoint:${RESET} ${CYAN}${endpoint}${RESET}"
        echo -e "${BOLD}Logs:${RESET}     $SERVER_LOG_FILE"
        echo ""
        echo "Commands:"
        echo "  llm-cli serve --status  Check server status"
        echo "  llm-cli serve --logs    View server logs"
        echo "  llm-cli serve --stop    Stop the server"

        # Show usage guide with actual model info from running server
        render_serve_usage_guide "$endpoint" "$SERVE_MODEL_NAME" "$api_key" "background"
    else
        log_error "Server failed to start within 30 seconds"
        echo "Check logs: cat $SERVER_LOG_FILE" >&2
        kill "$pid" 2>/dev/null
        rm -f "$SERVER_PID_FILE"
        return 1
    fi
}

# Stop background server
stop_server() {
    if [[ ! -f "$SERVER_PID_FILE" ]]; then
        log_error "No server PID file found"
        echo "Server may not be running in background mode." >&2
        return 1
    fi

    local pid
    pid=$(cat "$SERVER_PID_FILE")

    if ! kill -0 "$pid" 2>/dev/null; then
        log_warn "Server process not found (PID: $pid)"
        rm -f "$SERVER_PID_FILE"
        return 1
    fi

    log_info "Stopping server (PID: $pid)..."

    # Send SIGTERM for graceful shutdown
    kill "$pid" 2>/dev/null

    # Wait for process to terminate
    local waited=0
    while kill -0 "$pid" 2>/dev/null && [[ $waited -lt 10 ]]; do
        sleep 1
        ((waited++))
    done

    if kill -0 "$pid" 2>/dev/null; then
        # Force kill if still running
        log_warn "Server did not stop gracefully, forcing..."
        kill -9 "$pid" 2>/dev/null
    fi

    rm -f "$SERVER_PID_FILE"
    log_success "Server stopped"
}

# Show server status
server_status() {
    echo ""
    echo -e "${BOLD}Server Status${RESET}"
    print_line "=" 30
    echo ""

    if [[ -f "$SERVER_PID_FILE" ]]; then
        local pid
        pid=$(cat "$SERVER_PID_FILE")

        if kill -0 "$pid" 2>/dev/null; then
            echo -e "Status:   ${GREEN}running${RESET}"
            echo "PID:      $pid"
            echo "Log file: $SERVER_LOG_FILE"
            echo ""

            # Try to get endpoint info
            local endpoint="http://localhost:${DEFAULT_SERVER_PORT}"
            if curl -s -m 2 "${endpoint}/v1/models" >/dev/null 2>&1; then
                echo -e "Endpoint: ${CYAN}${endpoint}${RESET}"

                # Try to show loaded models
                local models
                models=$(get_available_models "$endpoint" 2)
                if [[ -n "$models" ]]; then
                    echo ""
                    echo "Loaded models:"
                    echo "$models" | while read -r model; do
                        echo "  - $model"
                    done
                fi
            fi
        else
            echo -e "Status:   ${YELLOW}not running${RESET} (stale PID file)"
            rm -f "$SERVER_PID_FILE"
        fi
    else
        echo -e "Status:   ${RED}not running${RESET}"
        echo ""
        echo "Start a server with:"
        echo "  llm-cli serve [MODEL]"
        echo "  llm-cli serve 1 --background"
    fi
    echo ""
}

# Show server logs
show_server_logs() {
    if [[ ! -f "$SERVER_LOG_FILE" ]]; then
        log_error "No log file found"
        return 1
    fi

    echo -e "${BOLD}Server Logs${RESET} (${SERVER_LOG_FILE})"
    print_line "-" 50
    echo ""

    # Use tail -f to follow logs
    tail -f "$SERVER_LOG_FILE"
}

# Render serve help
render_serve_help() {
    cat <<EOF
${BOLD}Usage:${RESET} llm-cli serve [MODEL] [OPTIONS]

${BOLD}Start an OpenAI-compatible API server using llama-server.${RESET}

${BOLD}MODEL:${RESET}
  N                     Cached model number (from 'llm-cli models list')
  user/repo             HuggingFace model ID (auto-download)
  /path/to/model.gguf   Direct file path
  (none)                Interactive model selection

${BOLD}OPTIONS:${RESET}
  -h, --help            Show this help message
  --port PORT           Server port (default: ${DEFAULT_SERVER_PORT})
  --host HOST           Bind address (default: ${DEFAULT_SERVER_HOST})
                        Use 0.0.0.0 to allow remote connections
  -c, --context N       Context size (default: ${CONTEXT_SIZE})
  -t, --threads N       CPU threads (default: ${THREADS})
  -ngl, --gpu-layers N  GPU layers to offload (default: ${GPU_LAYERS})
  -np, --parallel N     Parallel request slots (default: ${DEFAULT_SERVER_PARALLEL})
  --api-key KEY         Require API key for authentication

${BOLD}BACKGROUND MODE:${RESET}
  -b, --background      Run server in background
  --stop                Stop background server
  --status              Show server status
  --logs                Tail server logs

${BOLD}EXAMPLES:${RESET}
  # Start server with cached model (interactive)
  llm-cli serve

  # Start with specific cached model
  llm-cli serve 1

  # Start with custom port
  llm-cli serve 1 --port 8080

  # Allow remote connections
  llm-cli serve 1 --host 0.0.0.0

  # Run in background
  llm-cli serve 1 --background
  llm-cli serve --status
  llm-cli serve --stop

  # Auto-download HuggingFace model
  llm-cli serve bartowski/Llama-3.2-3B-Instruct-GGUF

${BOLD}API ENDPOINTS:${RESET}
  POST /v1/chat/completions   Chat completions (streaming supported)
  POST /v1/completions        Text completions
  POST /v1/embeddings         Generate embeddings
  GET  /v1/models             List loaded models
  GET  /health                Health check
  GET  /metrics               Prometheus metrics

${BOLD}ENVIRONMENT VARIABLES:${RESET}
  LLM_CLI_THREADS       Override thread count
  LLM_CLI_GPU_LAYERS    Override GPU layers
  LLM_CLI_CONTEXT_SIZE  Override context size

${BOLD}SEE ALSO:${RESET}
  llm-cli info --format openai      Show client configuration
  llm-cli info --format examples    Show code examples
EOF
}

# Main serve command handler
cmd_serve() {
    local model_arg=""
    local port="$DEFAULT_SERVER_PORT"
    local host="$DEFAULT_SERVER_HOST"
    local context="$CONTEXT_SIZE"
    local threads="$THREADS"
    local gpu_layers="$GPU_LAYERS"
    local parallel="$DEFAULT_SERVER_PARALLEL"
    local api_key=""
    local background=false
    local do_stop=false
    local do_status=false
    local do_logs=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h | --help)
                render_serve_help
                return 0
                ;;
            --port)
                port="$2"
                shift 2
                ;;
            --port=*)
                port="${1#--port=}"
                shift
                ;;
            --host)
                host="$2"
                shift 2
                ;;
            --host=*)
                host="${1#--host=}"
                shift
                ;;
            -c | --context)
                context="$2"
                shift 2
                ;;
            -t | --threads)
                threads="$2"
                shift 2
                ;;
            -ngl | --gpu-layers)
                gpu_layers="$2"
                shift 2
                ;;
            -np | --parallel)
                parallel="$2"
                shift 2
                ;;
            --api-key)
                api_key="$2"
                shift 2
                ;;
            --api-key=*)
                api_key="${1#--api-key=}"
                shift
                ;;
            -b | --background)
                background=true
                shift
                ;;
            --stop)
                do_stop=true
                shift
                ;;
            --status)
                do_status=true
                shift
                ;;
            --logs)
                do_logs=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Run 'llm-cli serve --help' for usage" >&2
                return 1
                ;;
            *)
                if [[ -z "$model_arg" ]]; then
                    model_arg="$1"
                else
                    log_error "Unexpected argument: $1"
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Handle status/stop/logs commands first
    if [[ "$do_status" == true ]]; then
        server_status
        return 0
    fi

    if [[ "$do_stop" == true ]]; then
        stop_server
        return $?
    fi

    if [[ "$do_logs" == true ]]; then
        show_server_logs
        return $?
    fi

    # Check for llama-server
    if ! check_server_binary; then
        return 1
    fi

    # Resolve model
    if ! resolve_model_for_serve "$model_arg"; then
        return 1
    fi

    # Check port availability
    if ! check_port_available "$port"; then
        local existing_pid
        existing_pid=$(get_port_process "$port")
        log_error "Port $port is already in use"
        if [[ -n "$existing_pid" ]]; then
            echo "Process using port: $existing_pid" >&2
        fi
        echo "Try a different port with --port <number>" >&2
        return 1
    fi

    # Show GPU memory info on NVIDIA systems
    show_gpu_memory_info

    # Display configuration
    display_serve_config \
        "$SERVE_MODEL_NAME" \
        "$SERVE_MODEL_PATH" \
        "$host" \
        "$port" \
        "$context" \
        "$threads" \
        "$gpu_layers" \
        "$parallel" \
        "$api_key"

    # Start server
    if [[ "$background" == true ]]; then
        start_server_background \
            "$SERVE_MODEL_PATH" \
            "$host" \
            "$port" \
            "$context" \
            "$threads" \
            "$gpu_layers" \
            "$parallel" \
            "$api_key"
    else
        start_server_foreground \
            "$SERVE_MODEL_PATH" \
            "$host" \
            "$port" \
            "$context" \
            "$threads" \
            "$gpu_layers" \
            "$parallel" \
            "$api_key"
    fi
}
