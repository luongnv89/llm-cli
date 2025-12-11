# Change: Add Developer Information Command

## Why
Developers using llm-cli want to integrate local GGUF models with AI coding tools (e.g., Claude Code, VSCode extensions). To do this, they need:
- The endpoint URL/address for their running llama.cpp server
- Configuration examples following OpenAI/Anthropic standards
- Step-by-step setup instructions for common AI tools
- Environment variable references for easy integration

This information is currently scattered or missing. A dedicated `info` command provides a single source of truth for integration details.

## What Changes
- Add a new `llm-cli info` command (no changes to existing commands)
- Show server endpoint information (URL, port, connectivity check)
- Provide configuration templates for popular AI tools (Claude Code, OpenAI-compatible tools, etc.)
- Display recommended environment variables and usage examples
- Support JSON output for programmatic access

## Impact
- **New capability**: `dev-info` (developer integration information)
- **Affected code**: `bin/llm-cli`, `lib/dev-info.sh` (new file)
- **No breaking changes**: Purely additive
- **User-visible**: New `llm-cli info` command
