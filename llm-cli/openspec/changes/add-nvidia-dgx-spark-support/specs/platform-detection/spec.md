## ADDED Requirements

### Requirement: Platform Auto-Detection
The system SHALL automatically detect the runtime platform on startup and configure appropriate defaults without requiring user intervention.

#### Scenario: macOS with Apple Silicon detected
- **WHEN** the tool runs on macOS (`uname -s` returns "Darwin")
- **THEN** the platform is identified as "macos"
- **AND** default GPU acceleration uses Metal backend
- **AND** default THREADS is set to 8
- **AND** default GPU_LAYERS is set to 99

#### Scenario: Linux with NVIDIA GPU detected
- **WHEN** the tool runs on Linux (`uname -s` returns "Linux")
- **AND** `nvidia-smi` command is available and returns successfully
- **THEN** the platform is identified as "linux-nvidia"
- **AND** default GPU acceleration uses CUDA backend
- **AND** default THREADS is set to 10 (optimized for DGX Spark P-cores)
- **AND** default GPU_LAYERS is set to 99

#### Scenario: Linux without NVIDIA GPU
- **WHEN** the tool runs on Linux
- **AND** `nvidia-smi` command is not available or fails
- **THEN** the platform is identified as "linux-cpu"
- **AND** GPU acceleration is disabled (GPU_LAYERS=0)
- **AND** default THREADS is set to available CPU cores

### Requirement: Platform Override
The system SHALL allow users to override auto-detected platform via command-line flag or environment variable for testing or unusual configurations.

#### Scenario: Manual platform selection via command-line flag
- **WHEN** the `--platform` flag is provided with a valid platform name
- **THEN** the system uses the specified platform instead of auto-detection
- **AND** applies configuration defaults for the specified platform
- **AND** the flag takes precedence over the environment variable

#### Scenario: Manual platform selection via environment variable
- **WHEN** the `LLM_CLI_PLATFORM` environment variable is set to a valid platform name
- **AND** no `--platform` flag is provided
- **THEN** the system uses the specified platform instead of auto-detection
- **AND** applies configuration defaults for the specified platform

#### Scenario: Invalid platform override
- **WHEN** the `--platform` flag or `LLM_CLI_PLATFORM` environment variable is set to an unrecognized value
- **THEN** the system logs a warning
- **AND** falls back to auto-detection

### Requirement: NVIDIA GPU System Information
The system SHALL report NVIDIA GPU details in benchmark reports when running on Linux with NVIDIA GPU.

#### Scenario: NVIDIA GPU info in benchmark report
- **WHEN** a benchmark is run on a Linux system with NVIDIA GPU
- **THEN** the benchmark report includes GPU model name
- **AND** the report includes GPU memory capacity
- **AND** the report includes CUDA driver version
- **AND** the report includes GPU temperature in Celsius
- **AND** the report includes GPU power draw in Watts

#### Scenario: nvidia-smi partial failure
- **WHEN** `nvidia-smi` is available but some queries fail
- **THEN** the system reports available information
- **AND** shows "Unknown" for failed queries
- **AND** does not fail the benchmark

### Requirement: Cross-Platform Dependency Guidance
The system SHALL provide platform-appropriate installation guidance for dependencies.

#### Scenario: Missing llama.cpp on macOS
- **WHEN** `llama-cli` is not found on macOS
- **THEN** the system suggests `brew install llama.cpp`

#### Scenario: Missing llama.cpp on Linux with NVIDIA GPU
- **WHEN** `llama-cli` is not found on Linux
- **AND** NVIDIA GPU is detected
- **THEN** the system suggests building from source with CUDA support
- **AND** provides or links to build instructions

#### Scenario: Missing llama.cpp on Linux without NVIDIA GPU
- **WHEN** `llama-cli` is not found on Linux
- **AND** no NVIDIA GPU is detected
- **THEN** the system suggests building from source or using apt package
- **AND** provides or links to build instructions

#### Scenario: NVIDIA GPU detected but CUDA unavailable
- **WHEN** `nvidia-smi` succeeds but llama.cpp lacks CUDA support
- **THEN** the system warns that GPU acceleration may not be available
- **AND** suggests rebuilding llama.cpp with CUDA flags

### Requirement: Platform Display in Configuration
The system SHALL display the detected platform in configuration output.

#### Scenario: Show detected platform
- **WHEN** user runs `llm-cli config`
- **THEN** the output includes a "Platform" field showing the detected or overridden platform name
