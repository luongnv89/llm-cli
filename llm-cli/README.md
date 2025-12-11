# llm-cli

A modular command-line tool for managing and running local LLMs with llama.cpp. Supports macOS (Apple Silicon), Linux with NVIDIA GPUs (including DGX Spark), and Linux CPU-only systems.

## Features

- **Search & Download**: Search HuggingFace for GGUF models and download with auto-quantization selection
- **Model Management**: List, inspect, delete, and update cached models
- **Chat**: Start interactive conversations with any cached model
- **Benchmarking**: Benchmark single models, batches, or all cached models
- **Statistics**: Track usage with full session history
- **Cross-Platform**: Auto-detects platform and applies optimal settings for your hardware

## Supported Platforms

| Platform | GPU Acceleration | Default Threads |
|----------|-----------------|-----------------|
| macOS (Apple Silicon) | Metal | 8 |
| Linux + NVIDIA GPU | CUDA | 10 (DGX Spark P-cores) |
| Linux (CPU-only) | None | Auto (all cores) |

## Installation

### macOS

```bash
# Install llama.cpp
brew install llama.cpp

# Clone and install llm-cli
git clone https://github.com/luongnv89/llm-cli.git
cd llm-cli
./install.sh
```

### Ubuntu / Linux with NVIDIA GPU (DGX Spark)

```bash
# Install build dependencies
sudo apt update && sudo apt install -y build-essential cmake git

# Build llama.cpp with CUDA support
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
cmake -B build -DGGML_CUDA=ON
cmake --build build --config Release
sudo cp build/bin/llama-* /usr/local/bin/

# Install llm-cli
cd ..
git clone https://github.com/luongnv89/llm-cli.git
cd llm-cli
./install.sh
```

### Ubuntu / Linux (CPU-only)

```bash
# Install build dependencies
sudo apt update && sudo apt install -y build-essential cmake git

# Build llama.cpp
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
cmake -B build
cmake --build build --config Release
sudo cp build/bin/llama-* /usr/local/bin/

# Install llm-cli
cd ..
git clone https://github.com/luongnv89/llm-cli.git
cd llm-cli
./install.sh
```

The installer creates a symlink in `~/.local/bin/`. Make sure this is in your PATH.

## Quick Start

```bash
# Quick way - auto-download & chat (no pre-download needed)
llm-cli chat bartowski/Llama-3.2-3B-Instruct-GGUF

# Or the traditional way - download first, then chat
llm-cli search llama-3.2
llm-cli download bartowski/Llama-3.2-3B-Instruct-GGUF
llm-cli models list
llm-cli chat

# Run a benchmark
llm-cli bench
```

## Commands

### Search & Download

```bash
# Search HuggingFace for GGUF models
llm-cli search <query>
llm-cli s llama-3.2

# Download a specific repository
llm-cli download <repo>
llm-cli d bartowski/Llama-3.2-3B-Instruct-GGUF
```

### Chat

```bash
# Auto-download & chat with HuggingFace model (recommended)
llm-cli chat bartowski/Llama-3.2-3B-Instruct-GGUF

# Auto-download with specific quantization
llm-cli chat bartowski/Llama-3.2-3B-Instruct-GGUF/Q4_K_M.gguf

# Send prompt and exit (non-interactive)
llm-cli chat bartowski/Llama-3.2-3B-Instruct-GGUF "What is 2+2?"

# Interactive model selection (from cached models)
llm-cli chat

# Run specific cached model by number
llm-cli chat 1
llm-cli c 2
```

### Model Management

```bash
# List all cached models
llm-cli models list

# Show detailed model info
llm-cli models info 1

# Delete a cached model
llm-cli models delete 1

# Update/re-download a model
llm-cli models update 1
```

### Benchmarking

```bash
# Benchmark single model (interactive)
llm-cli bench

# Benchmark specific model
llm-cli bench 1

# Benchmark all cached models
llm-cli bench --all

# Benchmark specific models
llm-cli bench --batch 1,2,3

# Save reports to custom directory
llm-cli bench --output ./my-reports
llm-cli bench --all -o /tmp/benchmarks

# View saved benchmark reports
llm-cli bench --reports
```

Benchmark results are automatically saved as Markdown reports. By default, reports are saved to `~/.local/share/llm-cli/benchmarks/`, but you can specify a custom directory with `--output`. Reports include:
- Model information (name, path, size)
- System information (platform, CPU/GPU, memory, llama.cpp version)
- NVIDIA GPU details (model, memory, temperature, power) when applicable
- Benchmark configuration (threads, GPU layers, tokens)
- Performance results (prompt processing, text generation speeds)
- Raw benchmark output

### Statistics

```bash
# Show usage statistics
llm-cli stats

# Clear all statistics
llm-cli stats --clear
```

### Configuration

```bash
# Show current configuration (includes detected platform)
llm-cli config

# Edit configuration file
llm-cli config --edit
```

## Configuration

Configuration is stored at `~/.config/llm-cli/config`. Default values are set based on your detected platform:

```bash
# Performance settings (auto-configured for your platform)
THREADS=8          # 8 for macOS, 10 for NVIDIA, auto for CPU-only
GPU_LAYERS=99      # 99 for GPU platforms, 0 for CPU-only
CONTEXT_SIZE=4096

# System prompt for chat sessions
SYSTEM_PROMPT="You are a helpful AI assistant."

# Output settings
NO_COLOR=0
VERBOSE=1
```

### Environment Variables

Override settings with environment variables:

```bash
LLM_CLI_THREADS=4 llm-cli chat
LLM_CLI_GPU_LAYERS=32 llm-cli bench
LLM_CLI_PLATFORM=linux-cpu llm-cli config  # Force platform
```

### Platform Override

Override auto-detected platform via command-line flag or environment variable:

```bash
# Command-line flag (highest priority)
llm-cli --platform linux-nvidia bench
llm-cli --platform linux-cpu chat
llm-cli --platform macos config

# Environment variable
LLM_CLI_PLATFORM=linux-nvidia llm-cli bench
```

Valid platform values: `macos`, `linux-nvidia`, `linux-cpu`

## Quantization Optimization

### MXFP4 for NVIDIA Blackwell (DGX Spark)

When searching for models on **DGX Spark** systems, llm-cli automatically prioritizes **MXFP4** quantization:

```
llm-cli search llama-3.2
# Shows: "💡 Platform Optimization Tip:
#         MXFP4 is specifically optimized for Blackwell architecture (DGX Spark)
#         Prefer MXFP4 models over standard Q4_K_M for best performance"
```

**Why MXFP4?**
- Specifically optimized for NVIDIA Blackwell architecture used in DGX Spark
- Delivers superior performance compared to standard quantizations
- Maintains accuracy while reducing memory requirements
- Ideal for running larger models on GPU

**How it works:**
1. When searching for models, look for MXFP4 variants first
2. During auto-download, MXFP4 is automatically selected if available
3. Fall back to Q5_K_M, Q4_K_M if MXFP4 not available

### Standard Quantization Priority

For other platforms (macOS, Linux CPU), the default quantization priority is:
1. Q5_K_M - Balanced quality and size
2. Q4_K_M - More aggressive quantization
3. Q6_K - Higher quality for larger contexts
4. Q4_K_S - Small quantization
5. Q8_0 - Full 8-bit quantization

## Model Selection Guide

### Recommended Model Sizes by GPU Memory

**llm-cli automatically shows GPU memory and model recommendations** when you run:
```bash
llm-cli models list    # Shows available models with GPU memory info
llm-cli chat 1         # Shows memory recommendations before starting chat
```

The tool detects your GPU VRAM and suggests appropriate model sizes:

#### 80GB+ VRAM (H100, H200, DGX Spark with full memory)
- ✅ **70B models** (Q4_K_M, MXFP4) - Excellent fit
- ✅ **20-30B models** (any quantization) - Optimal
- ✅ **7-13B models** (Q8_0, full precision) - Full GPU offload

#### 40GB VRAM (L40S)
- ✅ **30B models** (Q4_K_M, MXFP4) - Good fit
- ✅ **13B models** (Q8_0) - Recommended
- ⚠️ **7B models** (Q8_0) - Safer choice

#### 24GB VRAM (Typical DGX Spark config, RTX 6000)
- ✅ **13B models** (Q4_K_M, MXFP4) - Recommended
- ✅ **7B models** (Q8_0, full) - Best choice
- ⚠️ **3B models** (any) - Safe option

#### 12GB VRAM (RTX 4080, RTX 4090)
- ⚠️ **7B models** (Q4_K_M, MXFP4) - Try first
- ✅ **3B models** (Q8_0) - Recommended

#### <12GB VRAM
- ✅ **3B models** (Q4_K_M) - Recommended
- ⚠️ **7B models** (Q2_K, Q3_K) - May work, reduce GPU_LAYERS

### Troubleshooting Out of Memory (OOM)

If you get "CUDA error: out of memory":

**Option 1: Use smaller quantization**
```bash
llm-cli search llama-3.2      # Look for Q4_K_M or MXFP4 variants
llm-cli search llama-3.2-7b   # Search for smaller model size
```

**Option 2: Reduce GPU offloading**
```bash
LLM_CLI_GPU_LAYERS=50 llm-cli chat 1    # Offload fewer layers to GPU
LLM_CLI_GPU_LAYERS=30 llm-cli chat bartowski/Llama-3.2-3B-GGUF
```

**Option 3: Use CPU-only fallback**
```bash
LLM_CLI_PLATFORM=linux-cpu llm-cli chat 1   # Force CPU-only mode
```

## Data Storage

Following XDG Base Directory specification:

- **Config**: `~/.config/llm-cli/config`
- **Data**: `~/.local/share/llm-cli/stats.json`
- **Benchmarks**: `~/.local/share/llm-cli/benchmarks/` (Markdown reports)
- **Cache**: `~/.cache/llm-cli/`
- **Models**: `~/.cache/huggingface/hub/` (standard HuggingFace cache)

## Dependencies

### macOS

**Required:**
- `llama.cpp` (`brew install llama.cpp`)

**Optional:**
- `jq` - For full statistics features (`brew install jq`)

### Linux

**Required:**
- `llama.cpp` (build from source, see Installation)
- For NVIDIA GPU: CUDA toolkit and drivers

**Optional:**
- `jq` - For full statistics features (`sudo apt install jq`)

## Project Structure

```
llm-cli/
├── bin/
│   └── llm-cli          # Main entry point
├── lib/
│   ├── config.sh        # Configuration and platform detection
│   ├── utils.sh         # Utilities and logging
│   ├── models.sh        # Model management
│   ├── download.sh      # Search and download
│   ├── chat.sh          # Chat/conversation
│   ├── benchmark.sh     # Benchmarking
│   └── stats.sh         # Statistics tracking
├── completions/
│   ├── llm-cli.bash     # Bash completion
│   └── llm-cli.zsh      # Zsh completion
├── install.sh           # Cross-platform installation script
└── README.md
```

## Development

### Prerequisites

For development, install these additional tools:

**macOS:**
```bash
brew install shfmt shellcheck
pip install pre-commit
```

**Ubuntu:**
```bash
sudo apt install shfmt shellcheck
pip install pre-commit
```

### Setup

```bash
# Clone the repository
git clone https://github.com/luongnv89/llm-cli.git
cd llm-cli

# Install pre-commit hooks
pre-commit install
```

### Running Quality Checks

```bash
# Run all checks (same as CI)
pre-commit run --all-files

# Run individual checks
shfmt -i 4 -bn -ci -d bin/llm-cli lib/*.sh
shellcheck --severity=warning bin/llm-cli lib/*.sh
```

### Code Style

- 4-space indentation
- Use `set -euo pipefail` for strict error handling
- Quote all variable expansions
- Follow existing patterns in `lib/` modules

## License

MIT
