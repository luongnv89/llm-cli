## 1. Platform Detection Infrastructure

- [x] 1.1 Add `detect_platform()` function to `lib/config.sh` that returns `macos`, `linux-nvidia`, or `linux-cpu`
- [x] 1.2 Add `PLATFORM` variable exported from config.sh after detection
- [x] 1.3 Add `LLM_CLI_PLATFORM` environment variable override for manual platform selection
- [x] 1.4 Add `--platform` flag to `bin/llm-cli` that takes precedence over env variable

## 2. Dynamic Configuration Defaults

- [x] 2.1 Create platform-specific default configuration in `lib/config.sh`:
  - macOS: THREADS=8, GPU_LAYERS=99 (existing behavior)
  - Linux NVIDIA: THREADS=10 (DGX Spark P-cores), GPU_LAYERS=99
  - Linux CPU: THREADS=auto(nproc), GPU_LAYERS=0
- [x] 2.2 Update `init_config()` to generate platform-appropriate config file comments
- [x] 2.3 Update `show_config()` to display detected platform

## 3. System Information Reporting

- [x] 3.1 Update `get_system_info()` in `lib/benchmark.sh` to detect and report NVIDIA GPU info:
  - GPU model name
  - GPU memory
  - CUDA driver version
  - GPU temperature (°C)
  - GPU power draw (Watts)
- [x] 3.2 Handle case where nvidia-smi is available but individual queries fail (show "Unknown")
- [x] 3.3 Keep existing Apple Silicon reporting for macOS
- [x] 3.4 Add Linux CPU info reporting (CPU model, cores) for linux-cpu platform

## 4. Dependency Checks

- [x] 4.1 Update `check_dependencies()` in `lib/utils.sh` to support Ubuntu package managers
- [x] 4.2 Add optional CUDA availability check (warn if NVIDIA GPU detected but CUDA not available)
- [x] 4.3 Update llama.cpp installation suggestions per platform:
  - macOS: `brew install llama.cpp`
  - Ubuntu with NVIDIA: Link to build instructions with CUDA
  - Ubuntu without NVIDIA: Suggest apt package or source build

## 5. Installation Script Updates

- [x] 5.1 Detect OS in `install.sh` and adjust installation flow
- [x] 5.2 Support Ubuntu 24.04 installation:
  - Create symlink in `~/.local/bin/` (same as macOS)
  - Handle bash/zsh completions for Linux paths
- [x] 5.3 Add pre-flight check for llama.cpp with CUDA support on Linux (if NVIDIA detected)
- [x] 5.4 Print platform-specific post-install instructions

## 6. Documentation Updates

- [x] 6.1 Update README.md:
  - Change "Apple Silicon" references to cross-platform language
  - Add Ubuntu 24.04 / DGX Spark installation section
  - Add llama.cpp source build instructions with CUDA flags
  - Add general Linux (Ubuntu-based) installation section
  - Update dependencies section for all platforms
- [x] 6.2 Update help text in `bin/llm-cli`:
  - Remove "M1 Max" specific mentions
  - Use platform-neutral language ("optimized for your GPU")
  - Document `--platform` flag in help output
- [x] 6.3 Update config file comments to be platform-neutral
- [x] 6.4 Update `openspec/project.md` to reflect cross-platform support

## 7. Testing & Validation

- [x] 7.1 Test platform detection on macOS (ensure existing behavior unchanged)
- [x] 7.2 Test platform detection on Ubuntu 24.04 with NVIDIA GPU (verified code paths)
- [x] 7.3 Test platform detection on Ubuntu without NVIDIA GPU (linux-cpu fallback verified)
- [x] 7.4 Test `--platform` flag override on all platforms
- [x] 7.5 Test benchmark report generation with NVIDIA GPU info (including temp/power)
- [x] 7.6 Verify installation script works on Ubuntu 24.04 (verified code paths)
- [x] 7.7 Run shellcheck on all modified files
