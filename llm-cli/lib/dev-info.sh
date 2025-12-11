#!/bin/bash
# llm-cli: Developer integration information
# Provides endpoint information and configuration templates for tool integration

# Get endpoint from configuration with priority: flag > env var > config file > default
get_endpoint_url() {
    local flag_endpoint="${1:-}"

    # 1. Priority: CLI flag
    if [[ -n "$flag_endpoint" ]]; then
        echo "$flag_endpoint"
        return 0
    fi

    # 2. Priority: Environment variable
    if [[ -n "${LLM_ENDPOINT:-}" ]]; then
        echo "$LLM_ENDPOINT"
        return 0
    fi

    # 3. Priority: Config file
    if [[ -f "$CONFIG_FILE" ]]; then
        local config_endpoint
        config_endpoint=$(grep "^ENDPOINT=" "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 | tr -d '"')
        if [[ -n "$config_endpoint" ]]; then
            echo "$config_endpoint"
            return 0
        fi
    fi

    # 4. Default: localhost:8000
    echo "http://localhost:8000"
}

# Get port from endpoint URL
get_port_from_endpoint() {
    local endpoint="$1"
    # Extract port from URL (e.g., http://localhost:8080 -> 8080)
    # If no port specified, return default
    if [[ "$endpoint" =~ :([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "8000"
    fi
}

# Get local IP address (for remote connections)
get_local_ip() {
    local ip=""

    # Try to get local IP using various methods
    if command -v hostname &>/dev/null; then
        # Try hostname -I (Linux) or hostname (macOS fallback)
        if [[ "$PLATFORM" == "linux-"* ]]; then
            ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "")
        else
            # macOS: use ifconfig to get the first non-loopback IPv4
            ip=$(ifconfig 2>/dev/null | grep -E "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1 || echo "")
        fi
    fi

    # Fallback: if empty, try to determine via socket connection
    if [[ -z "$ip" ]]; then
        # Connect to a public DNS server and see what IP we use locally
        ip=$(bash -c "exec 3<>/dev/udp/8.8.8.8/53; echo -e '\\x00\\x00' >&3" 2>/dev/null || echo "")
        if [[ -z "$ip" ]]; then
            # Last resort: localhost
            ip="127.0.0.1"
        fi
    fi

    echo "$ip"
}

# Get list of available models from endpoint
get_available_models() {
    local endpoint="$1"
    local timeout="${2:-2}"

    if ! command -v curl &>/dev/null; then
        echo "# curl not available"
        return 1
    fi

    # Try to fetch models from /v1/models endpoint
    local models_json
    models_json=$(curl -s -m "$timeout" "${endpoint}/v1/models" 2>/dev/null)

    if [[ -z "$models_json" ]]; then
        return 1
    fi

    # Parse model IDs from JSON response
    # Response format: {"object":"list","data":[{"id":"model-name",...}]}
    # Extract just the IDs using grep and basic text processing (no jq for Bash 3.2 compat)
    echo "$models_json" | grep -oE '"id":"[^"]+' | cut -d'"' -f4 2>/dev/null || return 1
}

# Check endpoint connectivity status
check_endpoint_status() {
    local endpoint="$1"
    local timeout="${2:-2}"

    # Try to connect using curl with a simple HEAD or GET request
    if command -v curl &>/dev/null; then
        # Try the /health endpoint first (llama.cpp doesn't have this, so expect 404)
        # Then try /v1/models which should return a list
        if curl -s -m "$timeout" "${endpoint}/v1/models" >/dev/null 2>&1; then
            echo "running"
            return 0
        elif curl -s -m "$timeout" "$endpoint" >/dev/null 2>&1; then
            echo "running"
            return 0
        else
            echo "not-running"
            return 1
        fi
    else
        # Fallback: try bash TCP connection (if curl is not available)
        # This is a last resort for minimal environments
        if timeout "$timeout" bash -c "</dev/tcp/localhost/8000" 2>/dev/null; then
            echo "running"
            return 0
        else
            echo "not-running"
            return 1
        fi
    fi
}

# Render OpenAI-compatible configuration
render_openai_config() {
    local endpoint="$1"
    local local_ip
    local_ip=$(get_local_ip)

    cat <<EOF
${BOLD}OpenAI-Compatible Configuration${RESET}
=====================================

${BOLD}Connection URLs:${RESET}
  Localhost:  ${CYAN}${endpoint}/v1${RESET}
  Remote:     ${CYAN}http://${local_ip}:$(get_port_from_endpoint "$endpoint")/v1${RESET}

${BOLD}Authentication:${RESET}
  API Key:    sk-local (or leave empty)

${BOLD}Available Models:${RESET}
EOF

    # Try to fetch and display available models
    local models
    models=$(get_available_models "$endpoint")
    if [[ -n "$models" ]]; then
        echo "$models" | while read -r model; do
            echo "  • ${CYAN}${model}${RESET}"
        done
    else
        echo "  ${DIM}(none available - endpoint not running or no models loaded)${RESET}"
    fi

    cat <<EOF

${DIM}Example usage:${RESET}
  Python:
    from openai import OpenAI
    client = OpenAI(
        base_url="${endpoint}/v1",
        api_key="sk-local"
    )
    response = client.chat.completions.create(
        model="your-model-name",
        messages=[{"role": "user", "content": "Hello!"}]
    )
EOF
}

# Render Anthropic/Claude Code configuration
render_anthropic_config() {
    local endpoint="$1"
    cat <<EOF
${BOLD}Claude Code / Anthropic Integration${RESET}
=====================================
Provider:      OpenAI-compatible
Endpoint:      ${CYAN}${endpoint}/v1${RESET}
Model:         local-gguf (or your model name)
API Key:       sk-local (or dummy key)

${DIM}Setup in Claude Code:${RESET}
  1. Go to Settings → Custom API
  2. Select Provider: OpenAI
  3. Enter Endpoint: ${endpoint}/v1
  4. Set Model: local-gguf
  5. Set API Key: sk-local

Claude Code will use your local GGUF model for code completion and chat.
EOF
}

# Render environment variables template
render_env_vars() {
    local endpoint="$1"
    local port="$2"
    cat <<EOF
${BOLD}Environment Variables${RESET}
======================
${DIM}Add these to your shell profile or .env file:${RESET}

export LLM_ENDPOINT="${endpoint}"
export LLM_PORT="${port}"
export LLM_API_KEY="sk-local"

${DIM}Then in your code:${RESET}
  \$LLM_ENDPOINT  # Base endpoint URL
  \$LLM_PORT      # Server port
  \$LLM_API_KEY   # API key for requests
EOF
}

# Render code usage examples
render_code_examples() {
    local endpoint="$1"
    cat <<EOF
${BOLD}Code Examples${RESET}
==============

${CYAN}Python:${RESET}
  from openai import OpenAI

  client = OpenAI(
      base_url="${endpoint}/v1",
      api_key="sk-local"
  )

  response = client.chat.completions.create(
      model="your-model",
      messages=[{"role": "user", "content": "Hello"}],
      temperature=0.7,
      max_tokens=100
  )
  print(response.choices[0].message.content)

${CYAN}Node.js:${RESET}
  import OpenAI from "openai";

  const client = new OpenAI({
      baseURL: "${endpoint}/v1",
      apiKey: "sk-local",
  });

  const message = await client.chat.completions.create({
      model: "your-model",
      messages: [{ role: "user", content: "Hello" }],
      temperature: 0.7,
      max_tokens: 100,
  });
  console.log(message.choices[0].message.content);

${CYAN}Bash/cURL:${RESET}
  curl -s "${endpoint}/v1/chat/completions" \\
    -H "Content-Type: application/json" \\
    -d '{
      "model": "your-model",
      "messages": [{"role": "user", "content": "Hello"}],
      "temperature": 0.7,
      "max_tokens": 100
    }' | jq '.choices[0].message.content'
EOF
}

# Render default human-readable output
render_info_text() {
    local endpoint="$1"
    local port="$2"
    local status="$3"

    local status_color
    if [[ "$status" == "running" ]]; then
        status_color="${GREEN}${status}${RESET}"
    else
        status_color="${RED}${status}${RESET}"
    fi

    cat <<EOF
${BOLD}LLM CLI - Developer Integration Info${RESET}
======================================

${BOLD}Endpoint:${RESET}
  URL:    ${CYAN}${endpoint}${RESET}
  Port:   ${port}
  Status: ${status_color}

${BOLD}Configuration:${RESET}
  Platform:      ${PLATFORM}
  Config File:   ${CONFIG_FILE}
  Data Dir:      ${DATA_DIR}

${BOLD}Quick Links:${RESET}
  Run 'llm-cli info --format openai'    for OpenAI-compatible config
  Run 'llm-cli info --format anthropic' for Claude Code setup
  Run 'llm-cli info --format env'       for environment variables
  Run 'llm-cli info --format examples'  for code examples
  Run 'llm-cli info --json'             for JSON output

EOF
}

# Render help message
render_info_help() {
    cat <<EOF
${BOLD}Usage:${RESET} llm-cli info [OPTIONS]

${BOLD}Show developer integration information for connecting tools to your llama.cpp endpoint.${RESET}

${BOLD}OPTIONS:${RESET}
  -h, --help              Show this help message
  --endpoint <url>        Override detected endpoint
  --port <number>         Specify port (used with --endpoint)
  --format <type>         Show specific template:
                            openai      - OpenAI-compatible config
                            anthropic   - Claude Code integration
                            env         - Environment variables
                            examples    - Code usage examples
  --json                  Output as JSON
  --endpoint-only         Output just the endpoint URL
  --port-only             Output just the port number
  --status-only           Output just the server status

${BOLD}EXAMPLES:${RESET}
  llm-cli info
  llm-cli info --json
  llm-cli info --format openai
  llm-cli info --endpoint http://remote.server:9000
  llm-cli info --endpoint-only
  llm-cli info --format anthropic

${BOLD}ENVIRONMENT:${RESET}
  LLM_ENDPOINT            Custom endpoint URL (e.g., http://remote.server:8000)

${BOLD}CONFIGURATION:${RESET}
  Add to ~/.config/llm-cli/config:
  ENDPOINT=http://localhost:8000
EOF
}

# Render JSON output
render_info_json() {
    local endpoint="$1"
    local port="$2"
    local status="$3"

    # Build JSON manually to avoid jq dependency and ensure Bash 3.2 compatibility
    cat <<EOF
{
  "endpoint": "$endpoint",
  "port": $port,
  "status": "$status",
  "platform": "$PLATFORM",
  "config_file": "$CONFIG_FILE",
  "data_dir": "$DATA_DIR",
  "templates": {
    "openai": "Run 'llm-cli info --format openai' for details",
    "anthropic": "Run 'llm-cli info --format anthropic' for details",
    "env_vars": "Run 'llm-cli info --format env' for details",
    "examples": "Run 'llm-cli info --format examples' for details"
  }
}
EOF
}
