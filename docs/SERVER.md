# llm-cli API Server

The `llm-cli serve` command starts a `llama-server` instance that exposes an OpenAI-compatible API endpoint. This enables using your local LLMs with any application that supports the OpenAI API format.

## Quick Start

```bash
# Start server with interactive model selection
llm-cli serve

# Start with a specific cached model
llm-cli serve 1

# Test the server
curl http://localhost:8000/v1/models
```

## Server Configuration Options

### Basic Options

| Option | Default | Description |
|--------|---------|-------------|
| `--port PORT` | 8000 | Server port |
| `--host HOST` | 127.0.0.1 | Bind address (use `0.0.0.0` for all interfaces) |
| `-c, --context N` | 4096 | Context window size |
| `-t, --threads N` | Platform default | CPU threads |
| `-ngl, --gpu-layers N` | Platform default | GPU layers to offload |
| `-np, --parallel N` | 1 | Parallel request slots |
| `--api-key KEY` | None | Require API key authentication |

### Background Mode

| Option | Description |
|--------|-------------|
| `-b, --background` | Run server as daemon |
| `--stop` | Stop background server |
| `--status` | Show server status |
| `--logs` | Tail server logs |

### Examples

```bash
# Custom port and context size
llm-cli serve 1 --port 8080 --context 8192

# Allow remote connections with API key
llm-cli serve 1 --host 0.0.0.0 --api-key "my-secret-key"

# Run in background with custom settings
llm-cli serve 1 --background --port 9000 --parallel 4

# Check status and stop
llm-cli serve --status
llm-cli serve --stop
```

## API Endpoints Reference

### POST /v1/chat/completions

Chat completion endpoint (ChatGPT-style).

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-model",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "Hello!"}
    ],
    "temperature": 0.7,
    "max_tokens": 100
  }'
```

**Streaming:**

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-model",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": true
  }'
```

### POST /v1/completions

Text completion endpoint.

```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-model",
    "prompt": "Once upon a time",
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

### POST /v1/embeddings

Generate text embeddings.

```bash
curl http://localhost:8000/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-model",
    "input": "The food was delicious"
  }'
```

### GET /v1/models

List available models.

```bash
curl http://localhost:8000/v1/models
```

### GET /health

Health check endpoint.

```bash
curl http://localhost:8000/health
```

### GET /metrics

Prometheus metrics endpoint.

```bash
curl http://localhost:8000/metrics
```

## Client Integration Examples

### Python (OpenAI SDK)

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="sk-local"  # Can be any string if no --api-key set
)

response = client.chat.completions.create(
    model="local-model",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is the capital of France?"}
    ],
    temperature=0.7,
    max_tokens=100
)

print(response.choices[0].message.content)
```

**Streaming:**

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="sk-local"
)

stream = client.chat.completions.create(
    model="local-model",
    messages=[{"role": "user", "content": "Write a haiku about coding"}],
    stream=True
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
```

### Node.js (OpenAI SDK)

```javascript
import OpenAI from "openai";

const client = new OpenAI({
    baseURL: "http://localhost:8000/v1",
    apiKey: "sk-local",
});

async function main() {
    const response = await client.chat.completions.create({
        model: "local-model",
        messages: [
            { role: "system", content: "You are a helpful assistant." },
            { role: "user", content: "What is 2 + 2?" }
        ],
        temperature: 0.7,
        max_tokens: 100,
    });

    console.log(response.choices[0].message.content);
}

main();
```

### cURL

```bash
# Chat completion
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-model",
    "messages": [{"role": "user", "content": "Hello!"}]
  }' | jq '.choices[0].message.content'

# With API key
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer my-secret-key" \
  -d '{
    "model": "local-model",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Continue.dev (VS Code Extension)

Add to your `~/.continue/config.json`:

```json
{
  "models": [
    {
      "title": "Local LLM",
      "provider": "openai",
      "model": "local-model",
      "apiBase": "http://localhost:8000/v1",
      "apiKey": "sk-local"
    }
  ]
}
```

### Open WebUI

When running Open WebUI, configure the OpenAI API connection:

```bash
# Start Open WebUI with local LLM endpoint
docker run -d -p 3000:8080 \
  -e OPENAI_API_BASE_URL=http://host.docker.internal:8000/v1 \
  -e OPENAI_API_KEY=sk-local \
  --name open-webui \
  ghcr.io/open-webui/open-webui:main
```

Or set via the UI: Settings → Connections → OpenAI API → Set base URL to `http://localhost:8000/v1`

### LangChain (Python)

```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    base_url="http://localhost:8000/v1",
    api_key="sk-local",
    model="local-model",
    temperature=0.7,
)

response = llm.invoke("What is the meaning of life?")
print(response.content)
```

### LangChain (JavaScript)

```javascript
import { ChatOpenAI } from "@langchain/openai";

const model = new ChatOpenAI({
    openAIApiKey: "sk-local",
    configuration: {
        baseURL: "http://localhost:8000/v1",
    },
    modelName: "local-model",
    temperature: 0.7,
});

const response = await model.invoke("What is the meaning of life?");
console.log(response.content);
```

### Claude Code / Cursor

In Claude Code or Cursor, configure a custom OpenAI-compatible endpoint:

1. Go to Settings → Custom API or Model Settings
2. Select Provider: OpenAI (or OpenAI-compatible)
3. Set Base URL: `http://localhost:8000/v1`
4. Set API Key: `sk-local` (or your key if using `--api-key`)
5. Set Model: `local-model`

### Aider

```bash
# Set environment variables
export OPENAI_API_BASE=http://localhost:8000/v1
export OPENAI_API_KEY=sk-local

# Run aider with local model
aider --model openai/local-model
```

## Running as a System Service

### systemd (Linux)

Create `/etc/systemd/system/llm-server.service`:

```ini
[Unit]
Description=LLM API Server
After=network.target

[Service]
Type=simple
User=YOUR_USERNAME
ExecStart=/home/YOUR_USERNAME/.local/bin/llm-cli serve 1 --host 0.0.0.0 --port 8000
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable llm-server
sudo systemctl start llm-server
sudo systemctl status llm-server
```

### launchd (macOS)

Create `~/Library/LaunchAgents/com.llm-cli.server.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.llm-cli.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOUR_USERNAME/.local/bin/llm-cli</string>
        <string>serve</string>
        <string>1</string>
        <string>--port</string>
        <string>8000</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/llm-server.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/llm-server.err</string>
</dict>
</plist>
```

Load and start:

```bash
launchctl load ~/Library/LaunchAgents/com.llm-cli.server.plist
launchctl start com.llm-cli.server
```

## Security Considerations

### API Key Authentication

For production use, always set an API key:

```bash
llm-cli serve 1 --api-key "your-secure-key"
```

Clients must then include the key in requests:

```bash
curl http://localhost:8000/v1/models \
  -H "Authorization: Bearer your-secure-key"
```

### Network Binding

By default, the server binds to `127.0.0.1` (localhost only). To allow remote connections:

```bash
# Allow all interfaces (use with caution!)
llm-cli serve 1 --host 0.0.0.0

# Better: Use a reverse proxy (nginx, caddy) with TLS
```

### Firewall Recommendations

If exposing to a network:

```bash
# Linux (ufw)
sudo ufw allow from 192.168.1.0/24 to any port 8000

# macOS (pf)
# Add to /etc/pf.conf:
# pass in on en0 proto tcp from 192.168.1.0/24 to any port 8000
```

### Reverse Proxy with TLS

For production, use a reverse proxy with TLS:

**Caddy (automatic HTTPS):**

```
llm.example.com {
    reverse_proxy localhost:8000
}
```

**nginx:**

```nginx
server {
    listen 443 ssl;
    server_name llm.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Troubleshooting

### Server Won't Start

**Port already in use:**
```bash
# Check what's using the port
lsof -i :8000

# Use a different port
llm-cli serve 1 --port 8080
```

**Model not found:**
```bash
# List available models
llm-cli models list

# Download a model first
llm-cli search llama-3.2
llm-cli download bartowski/Llama-3.2-3B-Instruct-GGUF
```

### Out of Memory

**Reduce GPU layers:**
```bash
llm-cli serve 1 --gpu-layers 20
```

**Use smaller context:**
```bash
llm-cli serve 1 --context 2048
```

### Slow Response Times

**Increase parallel slots for concurrent requests:**
```bash
llm-cli serve 1 --parallel 4
```

**Optimize thread count:**
```bash
llm-cli serve 1 --threads 8
```

### Check Server Logs

```bash
# If running in background
llm-cli serve --logs

# Or directly
cat ~/.local/share/llm-cli/server.log
```

## Environment Variables

These environment variables affect server behavior:

| Variable | Description |
|----------|-------------|
| `LLM_CLI_THREADS` | Override thread count |
| `LLM_CLI_GPU_LAYERS` | Override GPU layers |
| `LLM_CLI_CONTEXT_SIZE` | Override context size |
| `LLM_CLI_PLATFORM` | Force platform detection |

Example:

```bash
LLM_CLI_GPU_LAYERS=30 LLM_CLI_CONTEXT_SIZE=8192 llm-cli serve 1
```

## Integration with llm-cli info

Use `llm-cli info` to get client configuration details:

```bash
# Show endpoint status and info
llm-cli info

# Get OpenAI-compatible configuration
llm-cli info --format openai

# Get code examples
llm-cli info --format examples

# Get JSON output for scripts
llm-cli info --json
```
