# Project Context

## Purpose
llm-cli is a modular command-line tool for managing and running local LLMs with llama.cpp. The primary goals are:
- Provide a unified interface to search, download, and manage GGUF models from HuggingFace
- Enable interactive chat sessions with locally-cached LLMs
- Support benchmarking for performance evaluation
- Track usage statistics and session history
- Auto-detect platform and optimize performance for the detected hardware

## Supported Platforms
- **macOS (Apple Silicon)**: Metal GPU acceleration, optimized for M1/M2/M3
- **Linux + NVIDIA GPU**: CUDA acceleration, optimized for DGX Spark
- **Linux (CPU-only)**: CPU inference for systems without GPU

## Tech Stack
- **Shell**: Bash (POSIX-compatible where possible, Bash 3.2+ for macOS compatibility)
- **Runtime**: llama.cpp (`llama-cli`)
  - macOS: `brew install llama.cpp`
  - Linux: Build from source with optional CUDA support
- **Model Source**: HuggingFace Hub (`huggingface-cli` for downloads)
- **Data Format**: JSON for stats/data files
- **Optional Tools**: `jq` for JSON processing

## Project Conventions

### Code Style
- Use `set -euo pipefail` at the top of all shell scripts for strict error handling
- Use `readonly` for constants that should never change
- Prefix all functions with descriptive names: `cmd_*` for commands, `log_*` for logging
- Use lowercase with underscores for variable and function names (snake_case)
- Quote all variable expansions: `"$variable"` not `$variable`
- Use `[[ ]]` for conditionals over `[ ]` where Bash-specific features are needed
- Add descriptive comments at the top of each library file

### Architecture Patterns
- **Modular Library Design**: Core functionality split into separate `.sh` files in `lib/`:
  - `config.sh` - Configuration management, platform detection, and XDG directory handling
  - `utils.sh` - Logging, colors, error handling, prompts, dependency checks
  - `models.sh` - Model listing, info, deletion, updates
  - `download.sh` - HuggingFace search and download
  - `chat.sh` - Interactive chat/conversation sessions
  - `benchmark.sh` - Performance benchmarking with platform-specific system info
  - `stats.sh` - Usage statistics tracking
- **Single Entry Point**: `bin/llm-cli` dispatches to command handlers
- **XDG Compliance**: Follow XDG Base Directory specification for config, data, and cache
- **Configuration Layering**: Platform defaults → Config file → Environment variables → CLI flags (highest priority)
- **Platform Detection**: Auto-detect at runtime, allow override via `--platform` flag or `LLM_CLI_PLATFORM` env var

### Testing Strategy
- Manual testing on macOS with Apple Silicon
- Manual testing on Linux with NVIDIA GPU (DGX Spark)
- Bash 3.2 compatibility testing (macOS default shell version)
- Test with various GGUF model sizes and quantization levels

### Git Workflow
- Main branch: `main`
- Commit messages: Short imperative description (e.g., "Add benchmark reports", "Fix compatibility issue")
- Do not include auto-generated markers or co-author tags in commits

## Domain Context
- **GGUF**: File format for LLM weights used by llama.cpp
- **Quantization**: Compression levels for models (Q4_K_M, Q5_K_M, Q6_K, Q8_0, etc.)
- **GPU Layers**: Number of layers offloaded to GPU (Metal/CUDA) for acceleration
- **Context Size**: Maximum tokens the model can process at once
- **HuggingFace Hub**: Primary source for downloading GGUF models
- **llama.cpp**: C++ inference engine for running LLMs locally
- **Platform Types**:
  - `macos`: macOS with Apple Silicon (Metal backend)
  - `linux-nvidia`: Linux with NVIDIA GPU (CUDA backend)
  - `linux-cpu`: Linux without GPU (CPU-only)

## Important Constraints
- Must support Bash 3.2 (macOS default) - no associative arrays (`declare -A`)
- Cross-platform: macOS (Apple Silicon), Linux (NVIDIA GPU), Linux (CPU-only)
- Must handle models with split files (e.g., `model-00001-of-00003.gguf`)
- Respect `NO_COLOR` environment variable for accessibility
- XDG Base Directory compliance for file storage

## External Dependencies

### macOS
- **llama.cpp** (required): Provides `llama-cli` for inference and benchmarking
  - Install: `brew install llama.cpp`
- **huggingface-cli** (optional): For searching and downloading models
  - Install: `pip install -U 'huggingface_hub[cli]'`
- **jq** (optional): For JSON parsing in statistics features
  - Install: `brew install jq`

### Linux (Ubuntu)
- **llama.cpp** (required): Build from source
  - With CUDA: `cmake -B build -DGGML_CUDA=ON && cmake --build build`
  - CPU-only: `cmake -B build && cmake --build build`
- **huggingface-cli** (optional): For searching and downloading models
  - Install: `pip install -U 'huggingface_hub[cli]'`
- **jq** (optional): For JSON parsing in statistics features
  - Install: `sudo apt install jq`
- **CUDA toolkit** (optional): For NVIDIA GPU acceleration
