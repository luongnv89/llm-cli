# llamacpp-mac

Tools for running local LLMs with llama.cpp on Apple Silicon Macs.

## Overview

This project provides command-line tools for managing and running local Large Language Models (LLMs) using [llama.cpp](https://github.com/ggerganov/llama.cpp) on macOS with Apple Silicon (M1/M2/M3/M4).

## Tools

### llm-cli

A modular CLI tool for complete LLM workflow management:

- **Search & Download** - Find and download GGUF models from HuggingFace
- **Model Management** - List, inspect, delete, and update cached models
- **Chat** - Interactive conversations with any cached model
- **Benchmarking** - Performance testing with detailed Markdown reports
- **Statistics** - Track usage with full session history

```bash
# Install
cd llm-cli && ./install.sh

# Quick start
llm-cli search llama-3.2
llm-cli download bartowski/Llama-3.2-3B-Instruct-GGUF
llm-cli chat
llm-cli bench
```

See [llm-cli/README.md](llm-cli/README.md) for full documentation.

## Requirements

### Required

- **macOS** with Apple Silicon (M1, M2, M3, M4)
- **llama.cpp** - Install with Homebrew:
  ```bash
  brew install llama.cpp
  ```

### Optional

- **huggingface-cli** - For downloading models from HuggingFace:
  ```bash
  pip install -U 'huggingface_hub[cli]'
  ```

- **jq** - For full statistics features:
  ```bash
  brew install jq
  ```

## Quick Start

1. **Install llama.cpp**:
   ```bash
   brew install llama.cpp
   ```

2. **Install llm-cli**:
   ```bash
   cd llm-cli
   ./install.sh
   ```

3. **Add to PATH** (if not already):
   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   ```

4. **Search and download a model**:
   ```bash
   llm-cli search llama-3.2
   # Select a model to download
   ```

5. **Start chatting**:
   ```bash
   llm-cli chat
   ```

6. **Run benchmarks**:
   ```bash
   llm-cli bench --all
   ```

## Performance

The tools are optimized for Apple Silicon with:

- **Metal GPU acceleration** - Full GPU offloading (99 layers by default)
- **Unified Memory** - Efficient memory usage on Apple Silicon
- **Optimized threading** - 8 threads by default for M1 Max

Default configuration can be customized in `~/.config/llm-cli/config`.

## Project Structure

```
llamacpp-mac/
├── llm-cli/                 # Main CLI tool
│   ├── bin/llm-cli          # Entry point
│   ├── lib/                 # Modular shell libraries
│   ├── completions/         # Shell completions (bash/zsh)
│   ├── install.sh           # Installation script
│   └── README.md            # Detailed documentation
├── run-llm.sh               # Legacy script (deprecated)
└── README.md                # This file
```

## Data Storage

Following XDG Base Directory specification:

| Type | Location |
|------|----------|
| Config | `~/.config/llm-cli/config` |
| Stats | `~/.local/share/llm-cli/stats.json` |
| Benchmarks | `~/.local/share/llm-cli/benchmarks/` |
| Models | `~/.cache/huggingface/hub/` |

## Sample Benchmark Report

After running `llm-cli bench`, you'll get detailed Markdown reports:

```markdown
# Benchmark Report

## Model
- **Name**: Llama-3.2-1B-Instruct-Q8_0-GGUF
- **Size**: 1.2G

## System Information
- **Chip**: Apple M1 Max
- **Memory**: 32 GB
- **llama.cpp version**: version: 7310 (db9783738)

## Results
| Metric | Value |
|--------|-------|
| Prompt Processing (pp) | 3585.59 t/s |
| Text Generation (tg) | 119.68 t/s |
```

## License

MIT
