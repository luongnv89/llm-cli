<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# llm-cli Development Guidelines

## Project Overview

llm-cli is a cross-platform Bash CLI for managing local LLMs with llama.cpp. It supports:
- **macOS** (Apple Silicon with Metal)
- **Linux + NVIDIA GPU** (CUDA, optimized for DGX Spark)
- **Linux CPU-only**

## Code Style

### Shell Script Conventions
- Always start scripts with `set -euo pipefail`
- Use `readonly` for constants
- Quote all variable expansions: `"$variable"` not `$variable`
- Use `[[ ]]` for conditionals (Bash-specific)
- Use snake_case for variables and functions
- Prefix functions: `cmd_*` for commands, `log_*` for logging

### Bash 3.2 Compatibility
- **No associative arrays** (`declare -A` not allowed)
- macOS ships with Bash 3.2 by default
- Test on macOS before committing

## Architecture

### File Structure
```
bin/llm-cli          # Entry point, command dispatcher
lib/
  config.sh          # Platform detection, configuration
  utils.sh           # Logging, colors, dependency checks
  models.sh          # Model management
  download.sh        # HuggingFace integration
  chat.sh            # Chat sessions
  benchmark.sh       # Benchmarking with system info
  stats.sh           # Usage statistics
```

### Platform Detection
Platform is auto-detected at startup:
- `macos` - Darwin + Apple Silicon
- `linux-nvidia` - Linux + nvidia-smi available
- `linux-cpu` - Linux without NVIDIA GPU

Override with `--platform <name>` or `LLM_CLI_PLATFORM` env var.

### Configuration Priority
1. CLI flags (highest)
2. Environment variables (`LLM_CLI_*`)
3. Config file (`~/.config/llm-cli/config`)
4. Platform defaults (lowest)

## Common Tasks

### Adding a New Command
1. Add handler function in appropriate `lib/*.sh` file
2. Add case in `bin/llm-cli` dispatcher
3. Update help text in `show_help()`

### Adding Platform-Specific Code
```bash
case "$PLATFORM" in
    macos)
        # Apple Silicon specific
        ;;
    linux-nvidia)
        # NVIDIA CUDA specific
        ;;
    linux-cpu)
        # CPU-only fallback
        ;;
esac
```

### Running Quality Checks
```bash
# Lint and format
shellcheck --severity=warning bin/llm-cli lib/*.sh
shfmt -i 4 -bn -ci -d bin/llm-cli lib/*.sh

# Or use pre-commit
pre-commit run --all-files
```

## Git Conventions

- Main branch: `main`
- Commit messages: Short imperative (e.g., "Add benchmark reports")
- Do NOT include auto-generated markers or co-author tags
- Do NOT commit without explicit user request
