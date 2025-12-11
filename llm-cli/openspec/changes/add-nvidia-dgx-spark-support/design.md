## Context

llm-cli was originally designed for macOS with Apple Silicon (Metal GPU acceleration). The tool hardcodes several assumptions:
- `brew install llama.cpp` as the installation method
- Metal-specific GPU layer settings (99 layers for full offload)
- macOS system commands (`sysctl`, `uname -s Darwin`)
- M1 Max-optimized thread counts (8 threads)

Nvidia DGX Spark is a compact AI workstation running Ubuntu 24.04 with NVIDIA GPUs (typically Grace Hopper or similar). These systems use CUDA for GPU acceleration and have different optimal configurations.

## Goals / Non-Goals

### Goals
- Support DGX Spark (Ubuntu 24.04 + NVIDIA GPU) as a first-class platform
- Auto-detect platform without requiring user configuration
- Provide optimal defaults for NVIDIA CUDA acceleration
- Maintain full backward compatibility with macOS/Apple Silicon
- Update documentation to reflect cross-platform support

### Non-Goals
- Support for AMD GPUs (ROCm) - out of scope for this change
- Automated llama.cpp installation (provide instructions, not automation)
- Windows support

## Decisions

### Decision 1: Platform Detection Strategy
**What**: Detect platform at runtime using `uname` and check for NVIDIA GPU via `nvidia-smi`
**Why**: Simple, reliable, no external dependencies. Allows the same codebase to work on both platforms.

```bash
detect_platform() {
    local os=$(uname -s)
    if [[ "$os" == "Darwin" ]]; then
        echo "macos"
    elif [[ "$os" == "Linux" ]] && command -v nvidia-smi &>/dev/null; then
        echo "linux-nvidia"
    else
        echo "linux-cpu"
    fi
}
```

### Decision 2: Configuration Defaults by Platform
**What**: Define platform-specific default values for THREADS, GPU_LAYERS, and backend settings
**Why**: Each platform has different optimal settings

| Setting | macOS (Apple Silicon) | Linux (NVIDIA) | Linux (CPU-only) |
|---------|----------------------|----------------|------------------|
| THREADS | 8 | 10 (DGX Spark P-cores) | Auto (nproc) |
| GPU_LAYERS | 99 (Metal) | 99 (CUDA) | 0 |
| Backend | Metal,BLAS | CUDA | CPU |

**DGX Spark CPU Note**: The Grace CPU in DGX Spark has two clusters with up to 5 P-cores and 5 E-cores each. For inference, we target the 10 P-cores (high-performance cores) as default, which provides optimal performance. Users can override via config if their workload benefits from different thread counts.

### Decision 3: llama.cpp Installation Approach
**What**: Document source build with CUDA support, don't automate
**Why**:
- CUDA setup varies by system configuration
- Source build ensures optimal CUDA integration
- Avoids package manager dependency issues on Ubuntu

### Decision 4: System Info Reporting
**What**: Detect and report NVIDIA GPU model, memory, driver version, temperature, and power in benchmarks
**Why**: Essential for comparing benchmark results across different GPUs and monitoring thermal/power conditions

```bash
if command -v nvidia-smi &>/dev/null; then
    echo "- **GPU**: $(nvidia-smi --query-gpu=name --format=csv,noheader)"
    echo "- **GPU Memory**: $(nvidia-smi --query-gpu=memory.total --format=csv,noheader)"
    echo "- **CUDA Driver**: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader)"
    echo "- **GPU Temperature**: $(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)°C"
    echo "- **GPU Power**: $(nvidia-smi --query-gpu=power.draw --format=csv,noheader)"
fi
```

### Decision 5: Command-Line Platform Override
**What**: Add `--platform` flag to override auto-detection
**Why**: Useful for testing, debugging, and unusual hardware configurations

```bash
llm-cli --platform linux-nvidia bench    # Force NVIDIA mode
llm-cli --platform linux-cpu chat        # Force CPU-only mode
llm-cli --platform macos config          # Force macOS mode (for testing)
```

The flag takes precedence over the `LLM_CLI_PLATFORM` environment variable, which takes precedence over auto-detection.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Platform detection may fail on unusual setups | Provide manual override via config/env variable |
| NVIDIA driver issues could cause crashes | Check nvidia-smi before using CUDA features |
| Different llama.cpp builds have different flags | Document required build flags for CUDA |
| Benchmark comparisons across platforms may confuse users | Clearly label platform in benchmark reports |

## Migration Plan

1. **Phase 1**: Add platform detection and dynamic defaults (backward compatible)
2. **Phase 2**: Update documentation to cross-platform language
3. **Phase 3**: Add NVIDIA-specific system info to benchmarks
4. **Phase 4**: Update installation script for Ubuntu 24.04

No breaking changes - existing macOS users see no difference.

## Resolved Questions

1. **Should we add a `--platform` flag?** → Yes, added as Decision 5
2. **What thread count is optimal for DGX Spark?** → 10 threads (targeting 10 P-cores across 2 clusters)
3. **Should benchmark reports include GPU temperature/power metrics?** → Yes, added to Decision 4
