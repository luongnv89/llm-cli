# Contributing to llamacpp-mac

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/llamacpp-mac.git
   cd llamacpp-mac
   ```
3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Requirements

- macOS with Apple Silicon (M1/M2/M3/M4)
- Bash 3.2+ (default on macOS)
- llama.cpp (`brew install llama.cpp`)
- huggingface-cli (`pip install huggingface_hub[cli]`)

### Project Structure

```
llamacpp-mac/
├── llm-cli/
│   ├── bin/llm-cli      # Main entry point
│   ├── lib/             # Shell library modules
│   │   ├── config.sh    # Configuration management
│   │   ├── utils.sh     # Utilities and logging
│   │   ├── models.sh    # Model management
│   │   ├── download.sh  # Search and download
│   │   ├── chat.sh      # Chat functionality
│   │   ├── benchmark.sh # Benchmarking
│   │   └── stats.sh     # Statistics tracking
│   ├── completions/     # Shell completions
│   └── install.sh       # Installation script
└── archive/             # Deprecated scripts
```

### Testing Changes

```bash
# Run the CLI directly without installing
./llm-cli/bin/llm-cli --help

# Test specific commands
./llm-cli/bin/llm-cli models list
./llm-cli/bin/llm-cli bench --help
```

## Code Style

### Shell Scripts

- Use `#!/bin/bash` shebang
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `local` for function variables
- Quote all variable expansions: `"$var"` not `$var`
- Use `${var:-default}` for optional parameters
- Maintain Bash 3.2 compatibility (macOS default)

### Bash 3.2 Compatibility

Avoid these Bash 4+ features:
- `${var,,}` lowercase - use `echo "$var" | tr '[:upper:]' '[:lower:]'`
- `declare -A` associative arrays - use indexed arrays or other patterns
- `|&` pipe stderr - use `2>&1 |`

### Naming Conventions

- **Functions**: `snake_case` (e.g., `scan_cached_models`)
- **Command functions**: `cmd_<command>` (e.g., `cmd_bench`)
- **Variables**: `UPPER_CASE` for constants, `lower_case` for locals
- **Files**: `lowercase.sh`

## Making Changes

### Adding a New Command

1. Create a new file in `llm-cli/lib/` or add to existing module
2. Add command dispatcher function `cmd_<name>()`
3. Register in `llm-cli/bin/llm-cli` main case statement
4. Update shell completions in `llm-cli/completions/`
5. Document in `llm-cli/README.md`

### Adding a New Feature

1. Identify the appropriate module in `lib/`
2. Add helper functions with descriptive names
3. Add `--help` documentation for new options
4. Update README if user-facing

## Submitting Changes

### Commit Messages

Use clear, descriptive commit messages:

```
Add --output option for benchmark reports

- Allow users to specify custom directory for reports
- Update help text and completions
- Add documentation to README
```

### Pull Request Process

1. Ensure your code follows the style guidelines
2. Test on macOS with Apple Silicon
3. Update documentation as needed
4. Create a pull request with:
   - Clear title describing the change
   - Description of what and why
   - Any testing performed

## Reporting Issues

When reporting issues, please include:

- macOS version (`sw_vers`)
- Chip type (M1, M2, etc.)
- llama.cpp version (`llama-cli --version`)
- Steps to reproduce
- Expected vs actual behavior
- Any error messages

## Feature Requests

Feature requests are welcome! Please:

1. Check existing issues first
2. Describe the use case
3. Explain the expected behavior
4. Consider if it fits the project scope

## Questions?

Feel free to open an issue for questions or discussions.
