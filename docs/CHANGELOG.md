# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-02-21

### Added
- `serve` command for OpenAI-compatible API server via llama-server
- OpenAI-compatible usage guide shown after `serve` starts
- Cross-platform installation script with one-line `curl` install
- Uninstall support via `scripts/install.sh --uninstall`
- Logo assets and README branding

### Fixed
- Use `--color auto` for newer llama-cli versions in chat command
- Unbound variable error when chat command called with no arguments
- Avoid sourcing `/etc/os-release` to prevent readonly variable conflict on some distros
- CI workflow updated to include `scripts/` directory and fix formatting
- Exclude placeholder API keys from secrets check
- Track `bin/llm-cli` in git (was incorrectly ignored by `.gitignore`)

### Changed
- Updated README tagline and added Hugging Face attribution
- Open source project files (CODE_OF_CONDUCT, SECURITY, templates)
- Documentation structure (ARCHITECTURE, DEVELOPMENT, CHANGELOG)
- GitHub issue and PR templates
- Flattened project structure (moved from `llm-cli/` subfolder to root)
- Updated CONTRIBUTING.md with current project info

### Removed
- Deprecated archive folder
- Unrelated Ollama documentation

## [1.0.0] - Initial Release

### Added
- **Search & Download**: Search HuggingFace for GGUF models
- **Model Management**: List, inspect, delete, and update cached models
- **Chat**: Interactive conversations with local LLMs
- **Benchmarking**: Performance testing with detailed reports
- **Statistics**: Usage tracking with session history
- **Cross-Platform Support**:
  - macOS with Apple Silicon (Metal)
  - Linux with NVIDIA GPU (CUDA)
  - Linux CPU-only
- **Auto-Download**: Automatic model download during chat
- **Platform Detection**: Auto-detects hardware and applies optimal settings
- **MXFP4 Support**: Optimized quantization for NVIDIA Blackwell/DGX Spark
- **Developer Info**: `llm-cli info` command for integration details
- **Shell Completions**: Bash and Zsh completion scripts
