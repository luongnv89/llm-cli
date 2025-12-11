# Change: Remove HuggingFace CLI Dependency from Download

## Why
Currently, llm-cli requires HuggingFace CLI tools (`huggingface-cli` in older versions or `hf` in newer versions) to download models. This creates an unnecessary dependency on Python and the HuggingFace CLI tool, which:
- Adds installation complexity for users who may not have Python
- Requires separate pip installation step
- Introduces dependency version management overhead
- Makes llm-cli harder to distribute/package (requires Python in runtime environment)
- Requires updating download code when HuggingFace CLI tool changes (huggingface-cli → hf transition)

Since llm-cli already uses curl for API calls (search), we can leverage curl for direct HTTPS downloads from HuggingFace, eliminating this external dependency entirely and future-proofing against HuggingFace CLI changes.

## What Changes
- Replace `huggingface-cli download` (old) and `hf download` (new) calls with curl-based HTTPS downloads
- Implement direct file downloading from HuggingFace CDN URLs
- Add progress tracking and resume capability to curl downloads
- Remove HuggingFace CLI tool requirement (both huggingface-cli and hf)
- Keep search functionality unchanged (already uses curl)
- Simplify user installation: just need `llama.cpp` (no Python/pip required)

## Impact
- **New capability**: Direct HTTPS model download without external CLI tools
- **Affected code**: `lib/download.sh` (modifications to download_file and download_files functions)
- **Breaking changes**: None - external API unchanged, internal only
- **User impact**: Simplified installation, one less dependency to install
- **Compatibility**: Works on all supported platforms (macOS, Linux with/without NVIDIA)
