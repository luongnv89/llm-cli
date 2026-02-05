# Architecture

This document describes the architecture and design of llm-cli.

## Overview

llm-cli is a modular Bash CLI application for managing local LLMs with llama.cpp. It follows a library-based architecture where functionality is split into focused modules.

## Design Principles

1. **Modularity**: Each feature lives in its own library file
2. **Platform Abstraction**: Platform detection happens once, modules use abstracted settings
3. **XDG Compliance**: Configuration, data, and cache follow XDG Base Directory spec
4. **Bash 3.2 Compatibility**: Works on macOS default shell without upgrades

## Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      bin/llm-cli                            │
│                   (Command Dispatcher)                      │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│   config.sh   │     │   utils.sh    │     │   models.sh   │
│  (Platform &  │     │  (Logging &   │     │   (Model      │
│   Settings)   │     │   Helpers)    │     │  Management)  │
└───────────────┘     └───────────────┘     └───────────────┘
        │                                           │
        ▼                                           ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│  download.sh  │     │   chat.sh     │     │ benchmark.sh  │
│  (Search &    │     │ (Interactive  │     │ (Performance  │
│   Download)   │     │    Chat)      │     │   Testing)    │
└───────────────┘     └───────────────┘     └───────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│   stats.sh    │     │  dev-info.sh  │     │  llama.cpp    │
│  (Usage       │     │  (Developer   │     │  (External    │
│   Tracking)   │     │   Info API)   │     │   Runtime)    │
└───────────────┘     └───────────────┘     └───────────────┘
```

## Module Responsibilities

### Core Modules

| Module | Purpose | Key Functions |
|--------|---------|---------------|
| `config.sh` | Platform detection, configuration management | `detect_platform()`, `load_config()`, `set_quant_priority()` |
| `utils.sh` | Logging, colors, helper utilities | `log_info()`, `log_error()`, `setup_colors()` |

### Feature Modules

| Module | Purpose | Key Functions |
|--------|---------|---------------|
| `models.sh` | Model discovery and management | `scan_cached_models()`, `cmd_models_list()`, `cmd_models_delete()` |
| `download.sh` | HuggingFace search and download | `cmd_search()`, `cmd_download()`, `auto_download_model()` |
| `chat.sh` | Interactive chat sessions | `cmd_chat()`, `start_chat_session()` |
| `benchmark.sh` | Performance benchmarking | `cmd_bench()`, `run_benchmark()`, `generate_report()` |
| `stats.sh` | Usage statistics tracking | `cmd_stats()`, `record_session()` |
| `dev-info.sh` | Developer integration info | `cmd_info()`, `render_info_json()` |

## Data Flow

### Model Discovery Flow

```
HuggingFace Cache (~/.cache/huggingface/hub/)
            │
            ▼
    scan_cached_models()
            │
            ▼
    Parse model metadata
            │
            ▼
    Return indexed model list
```

### Chat Session Flow

```
User Input (model selection)
            │
            ▼
    Resolve model path
            │
            ▼
    Apply platform settings
    (threads, GPU layers)
            │
            ▼
    Launch llama-cli
            │
            ▼
    Record statistics
```

## Platform Detection

The platform is detected once at startup:

```bash
detect_platform() {
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "macos"
    elif command -v nvidia-smi &>/dev/null; then
        echo "linux-nvidia"
    else
        echo "linux-cpu"
    fi
}
```

Platform-specific defaults are then applied:

| Setting | macOS | Linux NVIDIA | Linux CPU |
|---------|-------|--------------|-----------|
| `THREADS` | 8 | 10 | $(nproc) |
| `GPU_LAYERS` | 99 | 99 | 0 |
| Quant Priority | Q5_K_M first | MXFP4 first | Q5_K_M first |

## File System Layout

```
~/.config/llm-cli/
└── config                 # User configuration

~/.local/share/llm-cli/
├── stats.json            # Usage statistics
└── benchmarks/           # Benchmark reports (Markdown)

~/.cache/huggingface/hub/  # Model cache (shared with HF ecosystem)
└── models--*--*/
    └── snapshots/
        └── */
            └── *.gguf
```

## Extension Points

### Adding a New Command

1. Create function `cmd_<name>()` in appropriate module
2. Register in `bin/llm-cli` case statement
3. Add shell completion in `completions/`

### Adding Platform Support

1. Update `detect_platform()` in `config.sh`
2. Add platform-specific defaults in `init_config()`
3. Update quantization priority in `set_quant_priority()`

## Dependencies

- **Required**: `llama.cpp` (llama-cli, llama-bench)
- **Optional**: `jq` (for statistics features)
- **Runtime**: Bash 3.2+, curl, standard Unix tools
