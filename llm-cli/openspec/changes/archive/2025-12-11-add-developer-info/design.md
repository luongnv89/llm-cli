# Technical Design: Developer Information Command

## Context
Developers need to integrate llm-cli's GGUF models with external tools (Claude Code, VSCode extensions, Python scripts). Currently, they must manually discover:
- The endpoint URL and port for their llama.cpp server
- How to configure third-party tools to use their server
- Environment variables for programmatic access

A dedicated `info` command centralizes this knowledge and provides templates.

## Goals
- **Primary**: Enable easy integration with AI coding tools via standardized endpoint configuration
- **Secondary**: Provide platform-specific guidance (macOS vs Linux)
- **Non-goals**: Starting/stopping the llama.cpp server, managing ports, network configuration

## Architecture

### Components

#### 1. `lib/dev-info.sh` (New Library File)
Core functions:
- `get_llama_endpoint()` - Detect running llama-cli server
  - Check localhost:8000 (default port)
  - Check environment variable `LLM_ENDPOINT`
  - Check config file for endpoint setting
  - Return status (running/not-running) and endpoint URL
- `check_endpoint_status()` - Test connectivity via curl
- `render_openai_config()` - Output OpenAI-compatible config
- `render_anthropic_config()` - Output Anthropic/Claude Code config
- `render_env_vars()` - Output shell export commands
- `render_usage_examples()` - Output code snippets (Python, Node.js, etc.)

#### 2. `bin/llm-cli` Updates
- Add `cmd_info()` handler function
- Add case statement for `info` command in main dispatcher
- Update `show_help()` to document the info command

### Data Flow

```
User: llm-cli info

1. Detect endpoint:
   - Check if llama-cli is running (port 8000 by default)
   - Look for LLM_ENDPOINT environment variable
   - Look for endpoint in config file
   - Report status

2. Render output:
   - Default: Human-readable text (endpoint, status, config templates)
   - --json: Structured JSON (endpoint, port, status, templates)
   - --endpoint: Just the URL (for scripting)
   - --format: Specific template (openai, anthropic, env, examples)
```

## Configuration Standards

### OpenAI-Compatible Format
```
Endpoint: http://localhost:8000/v1
Model: gguf-model
API Key: (none required, can use dummy)
```

### Anthropic/Claude Code Format
```
Custom API:
  Provider: OpenAI-compatible
  Endpoint: http://localhost:8000/v1
  Model: local-gguf
  API Key: (skip or use dummy)
```

## Decisions

1. **Port Default**: Use 8000 (llama.cpp default for serving)
   - Rationale: Simplicity, follows llama.cpp conventions

2. **Endpoint Detection Order**:
   - Flag (`--endpoint`) > Env var > Config file > Default
   - Rationale: Consistent with llm-cli's configuration layering

3. **Output Formats**:
   - Text (default), JSON, single-field, template-specific
   - Rationale: Supports human usage, scripting, and tool integration

4. **No Server Management**: `info` only reports, doesn't start llama.cpp
   - Rationale: Keep command simple, avoid process management complexity

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| Endpoint detection fails if server uses custom port | Provide flag to override (`--endpoint`, `--port`) |
| Config templates become outdated | Document clearly they're templates, not guaranteed |
| Cross-platform connectivity issues | Test on macOS and Linux, document network requirements |
| JSON parsing in shell | Use simple, shell-safe JSON format (avoid nested objects) |

## Open Questions

1. Should we support reading endpoint from running llama-cli instance metadata?
   - **Answer**: Not initially; too complex. Use environment variables or config file.

2. Should we auto-detect model capabilities (context size, quantization)?
   - **Answer**: No; beyond scope. Focus on endpoint configuration only.

3. Should templates include auth/SSL options?
   - **Answer**: No; assume localhost/development. Users can extend manually.
