# Development Guide

This guide covers setting up a development environment and contributing code to llm-cli.

## Prerequisites

### Required

- Bash 3.2+ (default on macOS)
- llama.cpp installed and in PATH
- Git

### Development Tools

**macOS:**
```bash
brew install shfmt shellcheck
pip install pre-commit
```

**Ubuntu/Linux:**
```bash
sudo apt install shfmt shellcheck
pip install pre-commit
```

## Getting Started

### Clone and Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/llm-cli.git
cd llm-cli

# Install pre-commit hooks
pre-commit install

# Test the CLI directly (no install needed)
./bin/llm-cli --help
```

### Project Structure

```
├── bin/llm-cli          # Main entry point and dispatcher
├── lib/                 # Shell library modules
│   ├── config.sh        # Platform detection, configuration
│   ├── utils.sh         # Logging, colors, helpers
│   ├── models.sh        # Model management
│   ├── download.sh      # Search and download
│   ├── chat.sh          # Chat functionality
│   ├── benchmark.sh     # Benchmarking
│   ├── stats.sh         # Usage statistics
│   └── dev-info.sh      # Developer integration
├── completions/         # Shell completions
│   ├── llm-cli.bash
│   └── llm-cli.zsh
├── install.sh           # Installation script
└── docs/                # Documentation
```

## Code Style

### Shell Script Guidelines

1. **Shebang**: Always use `#!/bin/bash`
2. **Strict Mode**: Start scripts with `set -euo pipefail`
3. **Local Variables**: Use `local` in functions
4. **Quoting**: Always quote variable expansions: `"$var"`
5. **Indentation**: 4 spaces (no tabs)

### Bash 3.2 Compatibility

Avoid these Bash 4+ features:

```bash
# ❌ Don't use
${var,,}                    # Lowercase
${var^^}                    # Uppercase
declare -A array            # Associative arrays
|&                          # Pipe stderr

# ✅ Use instead
echo "$var" | tr '[:upper:]' '[:lower:]'
echo "$var" | tr '[:lower:]' '[:upper:]'
# Use indexed arrays or other patterns
2>&1 |
```

### Naming Conventions

```bash
# Constants (global)
UPPER_CASE="value"

# Local variables
local lower_case="value"

# Functions
snake_case_function() { }

# Command handlers
cmd_command_name() { }
```

## Development Workflow

### Making Changes

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature
   ```

2. **Make changes and test**:
   ```bash
   # Test your changes
   ./bin/llm-cli your-command --options

   # Run linters
   pre-commit run --all-files
   ```

3. **Commit with descriptive message**:
   ```bash
   git commit -m "Add feature X

   - Detailed description
   - What changed and why"
   ```

### Running Quality Checks

```bash
# Run all checks (same as CI)
pre-commit run --all-files

# Run individual checks
shfmt -i 4 -bn -ci -d bin/llm-cli lib/*.sh
shellcheck --severity=warning bin/llm-cli lib/*.sh

# Check specific file
shellcheck lib/models.sh
```

### Testing Locally

```bash
# Test without installing
./bin/llm-cli --help
./bin/llm-cli models list
./bin/llm-cli config

# Test with debug output
set -x
./bin/llm-cli chat 1
set +x
```

## Adding Features

### Adding a New Command

1. **Create the command function** in the appropriate module:
   ```bash
   # lib/mymodule.sh
   cmd_mycommand() {
       local arg="${1:-}"
       # Implementation
   }
   ```

2. **Register in dispatcher** (`bin/llm-cli`):
   ```bash
   case "$command" in
       mycommand | mc)
           cmd_mycommand "$@"
           ;;
   ```

3. **Add help text** to `show_help()`:
   ```bash
   ${CYAN}mycommand${RESET}, mc     Description of command
   ```

4. **Update shell completions**:
   ```bash
   # completions/llm-cli.bash
   "mycommand" | "mc")
       COMPREPLY=( ... )
       ;;
   ```

5. **Document in README.md**

### Adding a New Option

1. Add to the command's argument parsing
2. Update the command's `--help` output
3. Add shell completion for the option
4. Document in README.md

## Debugging

### Enable Debug Output

```bash
# Bash debug mode
bash -x ./bin/llm-cli chat 1

# Or within script
set -x  # Enable
set +x  # Disable
```

### Check Variable Values

```bash
# Add debug prints
echo "DEBUG: var=$var" >&2
```

### Test Platform Detection

```bash
# Override platform for testing
LLM_CLI_PLATFORM=linux-nvidia ./bin/llm-cli config
LLM_CLI_PLATFORM=linux-cpu ./bin/llm-cli config
```

## Common Issues

### ShellCheck Warnings

```bash
# SC2086: Quote to prevent word splitting
echo $var      # ❌
echo "$var"    # ✅

# SC2155: Declare and assign separately
local var=$(cmd)           # ❌
local var; var=$(cmd)      # ✅

# SC2034: Unused variable (may be used in sourced file)
# shellcheck disable=SC2034
EXPORTED_VAR="value"
```

### shfmt Formatting

```bash
# Auto-fix formatting
shfmt -i 4 -bn -ci -w bin/llm-cli lib/*.sh

# Check without modifying
shfmt -i 4 -bn -ci -d bin/llm-cli lib/*.sh
```

## Release Process

1. Update version in `lib/config.sh` (`LLM_CLI_VERSION`)
2. Update CHANGELOG.md
3. Create PR with changes
4. After merge, create GitHub release
