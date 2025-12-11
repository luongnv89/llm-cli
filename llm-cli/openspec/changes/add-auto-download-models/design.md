# Technical Design: Auto-Download Models from HuggingFace

## Context

llm-cli should support three methods for obtaining models, in priority order:

1. **First Priority - Auto-Download via llama.cpp** (Preferred)
   - llama.cpp's native `hf://` URL support
   - Most seamless experience
   - No separate download step needed
   - Model cached automatically after first run

2. **Second Priority - Manual Download via HuggingFace Tools** (Advanced users)
   - Use `hf download` or `huggingface-cli download` if available
   - For users who want to pre-cache models
   - More control over downloading process
   - Better for slow/unreliable networks (download separately from inference)

3. **Third Priority - Manual Download via Curl** (Fallback)
   - Direct HTTPS download using curl
   - Works when HuggingFace tools not available
   - Provides fallback for all users
   - Last resort option

We should leverage llama.cpp's auto-download in llm-cli to provide a seamless first-run experience while maintaining backward compatibility with manual download methods.

## Download Method Priority

```
User wants to chat with model
         ↓
    llm-cli chat {model-id}
         ↓
┌────────────────────────────────────────┐
│ 1st Choice: Auto-Download via llama.cpp│
│ ✅ No setup needed                      │
│ ✅ Works immediately                   │
│ ✅ Cached automatically                │
│ ✅ Best for most users                 │
└────────────────────────────────────────┘
         ↓ (if user wants to pre-cache)
┌────────────────────────────────────────┐
│ 2nd Choice: HF Tools (hf/huggingface-cli)
│ ✅ Explicit control                    │
│ ✅ Better for slow networks            │
│ ✅ Pre-cache before inference          │
│ ✅ Then use: llm-cli chat 1            │
└────────────────────────────────────────┘
         ↓ (if HF tools not available)
┌────────────────────────────────────────┐
│ 3rd Choice: Curl Direct Download       │
│ ✅ Works everywhere                    │
│ ✅ No Python needed                    │
│ ✅ Fallback option                     │
│ ✅ Then use: llm-cli chat 1            │
└────────────────────────────────────────┘
```

## Goals
- **Primary**: Enable users to run `llm-cli chat {hf-model-id}` without pre-downloading (via auto-download)
- **Secondary**: Reduce onboarding friction, simplify getting started
- **Tertiary**: Maintain `llm-cli download` command for advanced users who prefer pre-caching
  - Support HuggingFace tools (2nd priority download method)
  - Support curl fallback (3rd priority download method)

## Architecture

### Current Flow
```
User: llm-cli chat
  ↓
Prompts to select from cached models
  ↓
If model cached: runs immediately
If no models: tells user to run llm-cli download
```

### New Flow
```
User: llm-cli chat [hf-model-id]
  ↓
Option 1: If hf-model-id provided:
  └─→ Pass to llama-cli as hf://{id}
      llama.cpp auto-downloads on first run

Option 2: If no argument:
  └─→ Show cached models OR suggest auto-download option
```

## Implementation Details

### Model ID Format Support

llama.cpp supports:
```bash
# Direct HuggingFace model download
llama-cli -m hf://bartowski/Llama-3.2-3B-Instruct-GGUF/Llama-3.2-3B-Instruct-Q4_K_M.gguf

# Or with shorter syntax (auto-selects best quantization)
llama-cli -m hf://bartowski/Llama-3.2-3B-Instruct-GGUF
```

### Enhanced cmd_chat() Function

Current: Requires selecting from cached models
Enhanced: Accept model ID as argument

```bash
# Usage patterns after enhancement:
llm-cli chat                                # Interactive selection from cache
llm-cli chat 1                              # Use cached model #1
llm-cli chat bartowski/Llama-3.2-3B-GGUF  # Auto-download via llama.cpp
llm-cli chat 1 "What is 2+2?"              # Cached model with prompt
```

### Parameter Passing

When user provides HuggingFace model ID:
1. Validate format (contains `/` suggesting it's a repo ID, not cache index)
2. Build model parameter: `-m "hf://{id}"`
3. Pass to llama-cli with other chat options
4. llama.cpp handles download automatically on first run

### Error Handling

- If HuggingFace ID invalid: llama.cpp error message
- If network unavailable: llama.cpp error message
- If model doesn't exist: llama.cpp error message
- Let llama.cpp handle all error cases (it's designed for this)

## Decisions

1. **Prefer llama.cpp auto-download over llm-cli download**
   - Rationale: Simpler, no separate download step, llama.cpp already does it

2. **Keep `llm-cli download` for advanced use (caching)**
   - Rationale: Some users may want to pre-cache large models offline

3. **Support both cache-based and HuggingFace ID-based workflows**
   - Rationale: Backward compatibility, flexibility for different user preferences

4. **Let llama.cpp handle downloading**
   - Rationale: Don't duplicate functionality, llama.cpp is maintained and robust

5. **Use `hf://` prefix for HuggingFace models**
   - Rationale: Standard llama.cpp convention, clear intent

## Data Flow

```
User Input: "bartowski/Llama-3.2-3B-GGUF"
       ↓
[Validation] Contains "/" and doesn't match cache index?
       ↓
[Transform] Build model path: "hf://bartowski/Llama-3.2-3B-GGUF"
       ↓
[Execute] llama-cli -m "hf://..." --color ...
       ↓
[llama.cpp] Auto-downloads model on first run
       ↓
[Output] Chat session with downloaded model
```

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| Network required for first run | Clear messaging about requirement |
| Large download on slow networks | Suggest pre-download with `llm-cli download` |
| Model not found on HuggingFace | llama.cpp provides clear error messages |
| Confused between cache index and model ID | Validate input: cache index is numeric, model ID has "/" |

## Testing Strategy

1. **Happy path**: Download and run model first time
2. **Cache path**: Continue using cached models
3. **Error handling**: Invalid repo, network issues
4. **Input validation**: Distinguish between "1" (cache) and "org/model" (HuggingFace)
5. **Quantization selection**: Let llama.cpp select best quantization

## Open Questions

1. Should we auto-detect and suggest best quantization in HuggingFace ID?
   - Answer: No, let llama.cpp do it (it already does)

2. Should we cache auto-downloaded models after first run?
   - Answer: llama.cpp caches in HF_HOME by default, no action needed

3. Should we support specifying quantization in model ID?
   - Answer: Yes, users can specify: `repo/model/Q4_K_M.gguf`

## Migration Path

**For New Users:**
- Run `llm-cli chat bartowski/Llama-3.2-3B-GGUF`
- Model auto-downloads, ready to use

**For Existing Users (with cached models):**
- Continue using: `llm-cli chat 1`
- Or switch to auto-download: `llm-cli chat bartowski/Llama-3.2-3B-GGUF`
- Both workflows work simultaneously
