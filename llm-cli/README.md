# llm-cli

A modular command-line tool for managing and running local LLMs with llama.cpp on Apple Silicon.

## Features

- **Search & Download**: Search HuggingFace for GGUF models and download with auto-quantization selection
- **Model Management**: List, inspect, delete, and update cached models
- **Chat**: Start interactive conversations with any cached model
- **Benchmarking**: Benchmark single models, batches, or all cached models
- **Statistics**: Track usage with full session history
- **Optimized for M1 Max**: Pre-configured for optimal performance on Apple Silicon

## Installation

```bash
# Clone or download the repository
cd llm-cli

# Run the installer
./install.sh
```

The installer creates a symlink in `~/.local/bin/`. Make sure this is in your PATH.

## Quick Start

```bash
# Search for a model
llm-cli search llama-3.2

# Download a model
llm-cli download bartowski/Llama-3.2-3B-Instruct-GGUF

# List cached models
llm-cli models list

# Start a conversation
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
# Interactive model selection
llm-cli chat

# Run specific model by number
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
```

### Statistics

```bash
# Show usage statistics
llm-cli stats

# Clear all statistics
llm-cli stats --clear
```

### Configuration

```bash
# Show current configuration
llm-cli config

# Edit configuration file
llm-cli config --edit
```

## Configuration

Configuration is stored at `~/.config/llm-cli/config`:

```bash
# Performance settings (optimized for M1 Max)
THREADS=8
GPU_LAYERS=99
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
```

## Data Storage

Following XDG Base Directory specification:

- **Config**: `~/.config/llm-cli/config`
- **Data**: `~/.local/share/llm-cli/stats.json`
- **Cache**: `~/.cache/llm-cli/`
- **Models**: `~/.cache/huggingface/hub/` (standard HuggingFace cache)

## Dependencies

**Required:**
- `llama.cpp` (`brew install llama.cpp`)

**Optional:**
- `huggingface-cli` - For downloading models (`pip install huggingface_hub[cli]`)
- `jq` - For full statistics features (`brew install jq`)

## Project Structure

```
llm-cli/
├── bin/
│   └── llm-cli          # Main entry point
├── lib/
│   ├── config.sh        # Configuration management
│   ├── utils.sh         # Utilities and logging
│   ├── models.sh        # Model management
│   ├── download.sh      # Search and download
│   ├── chat.sh          # Chat/conversation
│   ├── benchmark.sh     # Benchmarking
│   └── stats.sh         # Statistics tracking
├── completions/
│   ├── llm-cli.bash     # Bash completion
│   └── llm-cli.zsh      # Zsh completion
├── install.sh           # Installation script
└── README.md
```

## License

MIT
