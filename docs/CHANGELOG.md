# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Open source project files (CODE_OF_CONDUCT, SECURITY, templates)
- Documentation structure (ARCHITECTURE, DEVELOPMENT, CHANGELOG)
- GitHub issue and PR templates

### Changed
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
