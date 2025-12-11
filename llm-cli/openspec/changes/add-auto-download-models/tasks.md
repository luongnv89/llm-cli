# Implementation Tasks

## 1. Enhanced Chat Command
- [ ] 1.1 Add parameter to cmd_chat() for model ID argument
- [ ] 1.2 Validate input: distinguish cache index vs HuggingFace ID
- [ ] 1.3 Build hf:// model path when HuggingFace ID provided
- [ ] 1.4 Pass to llama-cli with hf:// prefix

## 2. User Experience
- [ ] 2.1 Update cmd_chat() to show auto-download option
- [ ] 2.2 Add examples showing HuggingFace model ID usage
- [ ] 2.3 Show helpful messages for first-run downloads
- [ ] 2.4 Document auto-download vs pre-download workflows

## 3. Input Handling
- [ ] 3.1 Validate numeric input (cache index)
- [ ] 3.2 Detect HuggingFace model ID format (contains /)
- [ ] 3.3 Handle edge cases (empty input, invalid format)
- [ ] 3.4 Show clear usage examples

## 4. Documentation
- [ ] 4.1 Update README.md with auto-download examples
- [ ] 4.2 Document when to use cache vs auto-download
- [ ] 4.3 Show example: `llm-cli chat bartowski/Llama-3.2-3B-GGUF`
- [ ] 4.4 Explain first-run download behavior

## 5. Testing & Validation
- [ ] 5.1 Test with valid HuggingFace model ID
- [ ] 5.2 Test with cached model index (backward compatibility)
- [ ] 5.3 Test input validation (numeric vs model ID)
- [ ] 5.4 Test error handling (invalid model, network issues)
- [ ] 5.5 Test first-run download experience
- [ ] 5.6 Verify Bash 3.2 compatibility
