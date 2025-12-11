# dev-info Specification

## Purpose
TBD - created by archiving change add-developer-info. Update Purpose after archive.
## Requirements
### Requirement: Show Developer Integration Information
The system SHALL provide a command that displays information needed to integrate llm-cli with external AI tools and developers integrating GGUF models into their applications.

#### Scenario: Display endpoint information
- **WHEN** user runs `llm-cli info`
- **THEN** system displays:
  - Current endpoint URL (e.g., `http://localhost:8000`)
  - Server connectivity status (running/not running)
  - OpenAI-compatible API endpoint details
  - Anthropic/Claude Code integration example

#### Scenario: Provide configuration templates
- **WHEN** user runs `llm-cli info` or `llm-cli info --format openai`
- **THEN** system displays ready-to-use configuration snippets for:
  - OpenAI-compatible clients
  - Anthropic/Claude Code
  - Environment variables (bash export commands)
  - Code examples (Python, Node.js)

#### Scenario: Output in JSON format
- **WHEN** user runs `llm-cli info --json`
- **THEN** system outputs structured JSON containing:
  - `endpoint`: URL string
  - `port`: integer port number
  - `status`: "running" | "not-running"
  - `templates`: object with openai, anthropic, env_vars, examples

#### Scenario: Query specific endpoint field
- **WHEN** user runs `llm-cli info --endpoint` or `llm-cli info --port`
- **THEN** system outputs only the requested value (no extra formatting)

### Requirement: Detect Endpoint Configuration
The system SHALL detect the llama.cpp server endpoint using a priority-based configuration system.

#### Scenario: Default endpoint detection
- **WHEN** llama.cpp server is running on localhost:8000 (platform default)
- **THEN** system auto-detects and reports the endpoint as `http://localhost:8000`

#### Scenario: Custom endpoint via environment variable
- **WHEN** `LLM_ENDPOINT` environment variable is set (e.g., `http://remote.server:8080`)
- **THEN** system uses that endpoint instead of default

#### Scenario: Custom endpoint via config file
- **WHEN** config file (`~/.config/llm-cli/config`) contains `ENDPOINT=http://...`
- **THEN** system uses that endpoint (overrides auto-detect, lower priority than env var)

#### Scenario: Override via command flag
- **WHEN** user runs `llm-cli info --endpoint http://custom.url:9000`
- **THEN** system uses specified endpoint (highest priority)

### Requirement: Provide Integration Templates
The system SHALL provide ready-to-use configuration templates for popular AI tools following OpenAI and Anthropic standards.

#### Scenario: OpenAI-compatible template
- **WHEN** user runs `llm-cli info --format openai` or views default output
- **THEN** system displays:
  ```
  OpenAI-compatible Configuration:
  - Base URL: http://localhost:8000/v1
  - Model: (user's selected model)
  - API Key: (none required, or use placeholder)
  ```

#### Scenario: Anthropic/Claude Code template
- **WHEN** user runs `llm-cli info --format anthropic`
- **THEN** system displays configuration for Claude Code's custom API feature:
  ```
  Claude Code (Custom API):
  Provider: OpenAI-compatible
  Endpoint: http://localhost:8000/v1
  Model: local-gguf
  ```

#### Scenario: Environment variables template
- **WHEN** user runs `llm-cli info --format env`
- **THEN** system outputs bash-compatible export commands:
  ```
  export LLM_ENDPOINT=http://localhost:8000
  export LLM_API_KEY=sk-local
  ```

#### Scenario: Code usage examples
- **WHEN** user runs `llm-cli info --format examples`
- **THEN** system displays code snippets (Python, Node.js, bash) showing:
  - How to connect to the endpoint
  - Basic request structure
  - Error handling patterns

### Requirement: Test Endpoint Connectivity
The system SHALL verify that the detected endpoint is reachable.

#### Scenario: Server is running and responsive
- **WHEN** llama.cpp server is running and responding to requests
- **THEN** system reports status as `running` with confirmation message

#### Scenario: Server is not running
- **WHEN** endpoint cannot be reached (connection refused)
- **THEN** system reports status as `not-running` with helpful guidance

#### Scenario: Network connectivity issue
- **WHEN** endpoint is configured but unreachable (network error)
- **THEN** system reports status as `unreachable` with error details
