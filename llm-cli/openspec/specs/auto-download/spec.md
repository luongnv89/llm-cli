# auto-download Specification

## Purpose
TBD - created by archiving change add-auto-download-models. Update Purpose after archive.
## Requirements
### Requirement: Support HuggingFace Model IDs in Chat
The system SHALL support running chat with HuggingFace model identifiers, allowing llama.cpp to automatically download models on first run.

#### Scenario: Auto-download model on first run
- **WHEN** user runs `llm-cli chat bartowski/Llama-3.2-3B-GGUF`
- **THEN** llm-cli passes model to llama.cpp as `hf://bartowski/Llama-3.2-3B-GGUF`
- **AND** llama.cpp downloads the model from HuggingFace on first invocation
- **AND** user can start chatting immediately after download completes
- **AND** model is cached in HuggingFace cache directory for future use

#### Scenario: Specify quantization in HuggingFace ID
- **WHEN** user runs `llm-cli chat bartowski/Llama-3.2-3B-GGUF/Q4_K_M.gguf`
- **THEN** llm-cli passes exact model path to llama.cpp
- **AND** llama.cpp downloads the specified quantization
- **AND** user gets exact model they requested

#### Scenario: Automatic quantization selection
- **WHEN** user runs `llm-cli chat bartowski/Llama-3.2-3B-GGUF` without quantization suffix
- **THEN** llama.cpp auto-selects the best available quantization
- **AND** model downloads and runs without user needing to choose

### Requirement: Maintain Backward Compatibility
The system SHALL continue to support cached models while adding HuggingFace ID support.

#### Scenario: Use cached model by index
- **WHEN** user runs `llm-cli chat 1`
- **THEN** system uses first cached model (existing behavior)
- **AND** auto-download feature does not interfere
- **AND** users with pre-cached models continue to work unchanged

#### Scenario: Interactive selection from cache
- **WHEN** user runs `llm-cli chat` with no arguments
- **THEN** system shows cached models (existing behavior)
- **AND** user can select by number OR provide HuggingFace ID
- **AND** both workflows available simultaneously

### Requirement: Input Validation
The system SHALL distinguish between cache indices and HuggingFace model IDs.

#### Scenario: Numeric input treated as cache index
- **WHEN** user runs `llm-cli chat 1`
- **THEN** system recognizes "1" as cache index
- **AND** uses first cached model
- **AND** does NOT treat as HuggingFace ID

#### Scenario: Model ID with slash recognized as HuggingFace
- **WHEN** user runs `llm-cli chat bartowski/Llama-3.2-3B-GGUF`
- **THEN** system recognizes format contains `/`
- **AND** treats as HuggingFace repository/model ID
- **AND** passes to llama.cpp with `hf://` prefix

#### Scenario: Clear error on invalid input
- **WHEN** user provides invalid input
- **THEN** system shows helpful error message
- **AND** suggests valid formats: `llm-cli chat 1` or `llm-cli chat org/model`

### Requirement: First-Run Download Experience
The system SHALL provide clear feedback during model downloads.

#### Scenario: Show download progress
- **WHEN** first-run model download is in progress
- **THEN** user sees download information from llama.cpp
- **AND** progress is visible
- **AND** user understands download is happening

#### Scenario: Cache model after download
- **WHEN** HuggingFace model finishes downloading
- **THEN** model is stored in HuggingFace cache directory
- **AND** future runs use cached version (no re-download)
- **AND** model persists across sessions

### Requirement: Support Prompts with HuggingFace Models
The system SHALL allow prompts to be provided along with HuggingFace model IDs.

#### Scenario: Run with initial prompt
- **WHEN** user runs `llm-cli chat bartowski/Llama-3.2-3B-GGUF "What is 2+2?"`
- **THEN** model downloads if needed
- **AND** initial prompt is sent immediately
- **AND** user gets response without interactive session

#### Scenario: Interactive chat after auto-download
- **WHEN** user runs `llm-cli chat bartowski/Llama-3.2-3B-GGUF` without prompt
- **THEN** model downloads if needed
- **AND** interactive chat session starts
- **AND** user can continue conversation
