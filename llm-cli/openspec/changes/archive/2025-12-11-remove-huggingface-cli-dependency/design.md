# Technical Design: Remove HuggingFace CLI Dependency

## Context
HuggingFace models are stored in cloud repositories accessible via HTTPS. The HuggingFace CLI tools (`huggingface-cli` in older versions or `hf` in newer versions) provide convenient wrappers around these downloads, but they're unnecessary abstractions since:
- We already use curl for HuggingFace API calls (search)
- Direct HTTPS downloads are straightforward with curl
- No special authentication needed for public models
- Eliminates need to track changes in HuggingFace CLI tool interface

## Goals
- **Primary**: Eliminate Python/HuggingFace CLI tool dependency (both huggingface-cli and hf)
- **Secondary**: Maintain or improve download robustness, future-proof against tool changes
- **Non-goals**: Implement private/gated model access, authentication systems

## Architecture

### Current Flow
```
User: llm-cli download <repo>
  ↓
fetch_repo_files() → HuggingFace API (curl) → file list
  ↓
User selects quantization
  ↓
download_file() → huggingface-cli/hf download → model.gguf
                   (Python tool, external dependency)
```

### New Flow
```
User: llm-cli download <repo>
  ↓
fetch_repo_files() → HuggingFace API (curl) → file list
  ↓
User selects quantization
  ↓
download_file() → Direct HTTPS (curl) → model.gguf
```

### Implementation Details

#### HuggingFace URL Structure
HuggingFace CDN URLs follow this pattern:
```
https://huggingface.co/{repo}/resolve/main/{filename}
```

For example:
```
https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf
```

#### Curl Implementation
```bash
curl -L \
  --progress-bar \
  --output "model.gguf" \
  "https://huggingface.co/{repo}/resolve/main/{filename}"
```

Key curl flags:
- `-L`: Follow redirects (important for CDN)
- `--progress-bar`: Show progress bar
- `--output`: Save to file
- Can add `--continue-at -` for resume capability

#### Download Directory
Files are downloaded to HuggingFace cache directory (same as huggingface-cli):
```
~/.cache/huggingface/hub/models--{repo}/{filename}
```

This ensures:
- Compatibility with existing cached models
- Models are reusable across tools
- Standard XDG cache location

#### Error Handling
- Check HTTP response code (200, 302, etc.)
- Retry on network errors
- Provide meaningful error messages
- Show download progress

## Decisions

1. **Use curl instead of wget**
   - Rationale: Already project dependency, better error handling, cookie support

2. **Direct CDN URLs vs API download endpoint**
   - Rationale: CDN URLs are simple, well-documented, and don't require additional API calls

3. **No authentication support initially**
   - Rationale: Public models work without auth; can add in future if needed

4. **Keep HuggingFace cache directory structure**
   - Rationale: Maintains compatibility with other tools, standard location

5. **Remove both huggingface-cli and hf command checks**
   - Rationale: No longer needed with curl-based implementation
   - Future-proof: Won't break if HuggingFace changes their CLI tool name again

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| CDN URL structure changes | HuggingFace unlikely to change, but fallback to API if needed |
| Large file downloads on slow networks | Add `--max-time` option for timeout control |
| Resume/partial downloads | Curl supports `--continue-at -` for automatic resume |
| Model file corruption | Verify file exists and size matches after download |

## Testing Strategy

1. **Unit tests**: Download function with mocked URLs
2. **Integration tests**: Download actual small models from HuggingFace
3. **Platform tests**: Test on macOS and Linux
4. **Edge cases**:
   - Network interruptions (test with timeout)
   - Large files (>10GB)
   - Split models (multiple parts)
   - Non-existent models

## Open Questions

1. Should we verify file checksums?
   - Answer: Not initially; HuggingFace serves from trusted CDN

2. Should we support downloading via API token?
   - Answer: Not initially; public models work without auth

3. Should we cache the file list to avoid repeated API calls?
   - Answer: No; keep it simple for first version
