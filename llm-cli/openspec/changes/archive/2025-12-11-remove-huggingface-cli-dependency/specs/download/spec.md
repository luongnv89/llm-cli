# Download Functionality Specification (Modified)

## MODIFIED Requirements

### Requirement: Download GGUF Models from HuggingFace
The system SHALL download GGUF models from HuggingFace repositories using curl-based HTTPS downloads without requiring external CLI tools.

#### Scenario: Download single GGUF model
- **WHEN** user runs `llm-cli download <repo>` and selects a quantization
- **THEN** system downloads the model file directly using curl
- **AND** file is saved to HuggingFace cache directory
- **AND** download shows progress bar
- **AND** success message is displayed upon completion

#### Scenario: Download multi-part/split model
- **WHEN** user runs `llm-cli download <repo>` for a split model
- **THEN** system downloads each part sequentially using curl
- **AND** all parts are saved to HuggingFace cache directory
- **AND** progress is shown for each part with count (1/3, 2/3, etc.)
- **AND** all parts download successfully before displaying success

#### Scenario: Handle download errors gracefully
- **WHEN** download fails due to network error
- **THEN** system displays error message with details
- **AND** user is informed about the failure
- **AND** partial downloads are cleaned up if appropriate

#### Scenario: Resume interrupted downloads
- **WHEN** a previous download was interrupted
- **THEN** system can resume the download from where it left off
- **AND** progress bar shows resume status
- **AND** user doesn't need to restart download

### Requirement: No External Dependency on HuggingFace CLI Tools
The system SHALL complete model downloads without requiring the HuggingFace CLI tool (huggingface-cli or hf) or Python installation.

#### Scenario: Download works without HuggingFace CLI tools installed
- **WHEN** neither huggingface-cli nor hf command is available
- **THEN** model download still succeeds
- **AND** no warning or error about missing HuggingFace CLI tools appears
- **AND** download completes normally using native curl
- **AND** works regardless of which HuggingFace CLI tool name is in use

#### Scenario: Compatibility with existing cache
- **WHEN** models are downloaded with new curl-based system
- **THEN** they are stored in standard HuggingFace cache directory
- **AND** models are compatible with other HuggingFace tools
- **AND** search and chat commands work with downloaded models

### Requirement: Progress Feedback During Download
The system SHALL provide visual feedback to the user during model downloads.

#### Scenario: Show download progress
- **WHEN** download is in progress
- **THEN** progress bar is displayed
- **AND** percentage and speed information are shown
- **AND** estimated time remaining is provided (if available)

#### Scenario: Indicate multi-part download progress
- **WHEN** downloading split models with multiple parts
- **THEN** each part shows individual progress
- **AND** overall progress indicates (1/3 downloading, 2/3 downloading, etc.)
- **AND** user can see which part is currently downloading
