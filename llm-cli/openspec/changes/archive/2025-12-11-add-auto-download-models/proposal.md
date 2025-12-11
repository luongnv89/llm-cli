# Change: Add Auto-Download Models from HuggingFace

## Why
Currently, llm-cli requires users to manually download models before using them. This is a friction point in the user experience:
- Users must explicitly run `llm-cli download` before they can chat
- Adds extra step to getting started
- llama.cpp itself supports auto-downloading GGUF models from HuggingFace on first run
- We should leverage this native llama.cpp capability instead of requiring pre-downloaded models

By integrating llama.cpp's auto-download feature, we can:
- Enable seamless first-time experience - just run `llm-cli chat <repo/model>`
- Reduce setup friction
- Rely on llama.cpp's robust model downloading (it already handles this)
- Keep llm-cli simple - delegate downloading to llama.cpp
- Support the HuggingFace model identifier format directly

## What Changes
- Add support for passing HuggingFace model identifiers directly to llama.cpp
- Allow users to run `llm-cli chat bartowski/Llama-3.2-3B-Instruct-GGUF` without pre-downloading
- llama.cpp will auto-download the best quantization on first run
- Maintain backward compatibility with cached local models
- Make the `llm-cli download` command optional for advanced users
- Add guidance showing how to use auto-download feature

## Impact
- **New capability**: Direct HuggingFace model IDs in chat (auto-download via llama.cpp)
- **Affected code**: `lib/chat.sh`, potentially `lib/models.sh`
- **Breaking changes**: None - cache-based workflow still works
- **User impact**: Simpler onboarding, fewer setup steps
- **Compatibility**: Works on all platforms that llama.cpp supports
