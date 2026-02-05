# Contributing to llm-cli

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/llm-cli.git
   cd llm-cli
   ```
3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Requirements

- macOS with Apple Silicon, Linux with NVIDIA GPU, or Linux CPU-only
- Bash 3.2+ (default on macOS)
- llama.cpp (`brew install llama.cpp` on macOS, build from source on Linux)

### Project Structure

```
├── bin/llm-cli          # Main entry point
├── lib/                 # Shell library modules
│   ├── config.sh        # Configuration management
│   ├── utils.sh         # Utilities and logging
│   ├── models.sh        # Model management
│   ├── download.sh      # Search and download
│   ├── chat.sh          # Chat functionality
│   ├── benchmark.sh     # Benchmarking
│   ├── stats.sh         # Statistics tracking
│   └── dev-info.sh      # Developer integration info
├── completions/         # Shell completions
└── install.sh           # Installation script
```

### Testing Changes

```bash
# Run the CLI directly without installing
./bin/llm-cli --help

# Test specific commands
./bin/llm-cli models list
./bin/llm-cli bench --help
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

1. Create a new file in `lib/` or add to existing module
2. Add command dispatcher function `cmd_<name>()`
3. Register in `bin/llm-cli` main case statement
4. Update shell completions in `completions/`
5. Document in `README.md`

### Adding a New Feature

1. Identify the appropriate module in `lib/`
2. Add helper functions with descriptive names
3. Add `--help` documentation for new options
4. Update `README.md` if user-facing

## Submitting Changes

### Branching Strategy

- Create feature branches from `main`
- Use descriptive branch names: `feature/add-export-command`, `fix/benchmark-parsing`
- Keep branches focused on a single change

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>: <description>

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```
feat: add --output option for benchmark reports

- Allow users to specify custom directory for reports
- Update help text and completions
- Add documentation to README

fix: correct model path parsing for spaces in filenames

docs: update installation instructions for Ubuntu 24.04
```

### Pull Request Process

1. Ensure your code follows the style guidelines
2. Test on your platform (macOS, Linux NVIDIA, or Linux CPU)
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

## Documentation

When making user-facing changes:

1. Update `README.md` for new features or changed behavior
2. Update shell completions if adding commands/options
3. Add inline help (`--help`) for new commands

For architecture changes, update `docs/ARCHITECTURE.md`.

## Questions?

Feel free to open an issue for questions or discussions.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).
