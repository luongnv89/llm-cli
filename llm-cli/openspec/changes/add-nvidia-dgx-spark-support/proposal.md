# Change: Add Nvidia DGX Spark Platform Support

## Why

llm-cli is currently optimized exclusively for Apple Silicon (M1/M2/M3 Macs with Metal GPU). Users with Nvidia DGX Spark workstations running Ubuntu 24.04 cannot leverage the tool's full potential. DGX Spark provides excellent CUDA-capable GPUs that can significantly accelerate llama.cpp inference, but require different configuration defaults and installation procedures.

## What Changes

- **Platform Detection**: Auto-detect platform (macOS/Apple Silicon vs Linux/NVIDIA CUDA) at runtime
- **Dynamic Configuration**: Apply optimal default settings based on detected platform:
  - Apple Silicon: Metal backend, existing defaults
  - NVIDIA GPU: CUDA backend, NVIDIA-optimized thread/layer settings
- **Installation Support**: Update `install.sh` to support Ubuntu 24.04 with instructions for building llama.cpp from source with CUDA
- **System Info**: Enhance `get_system_info()` in benchmark.sh to report NVIDIA GPU details
- **Documentation**: Rebrand project as cross-platform, update README and help text
- **Dependency Checks**: Add CUDA/nvidia-smi detection alongside existing llama.cpp checks

## Impact

- Affected specs: New capability `platform-detection`
- Affected code:
  - `lib/config.sh` - Platform detection and dynamic defaults
  - `lib/benchmark.sh` - NVIDIA system info reporting
  - `lib/utils.sh` - Dependency checks for CUDA
  - `install.sh` - Ubuntu/CUDA installation flow
  - `README.md` - Cross-platform documentation
  - `bin/llm-cli` - Help text updates
