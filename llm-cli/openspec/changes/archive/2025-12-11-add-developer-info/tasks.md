# Implementation Tasks

## 1. Core Implementation
- [x] 1.1 Create `lib/dev-info.sh` with endpoint detection logic
- [x] 1.2 Implement endpoint status checking (test connectivity)
- [x] 1.3 Add `cmd_info()` handler to `bin/llm-cli`
- [x] 1.4 Wire `info` command into main dispatcher

## 2. Configuration Templates
- [x] 2.1 Add OpenAI-compatible configuration template
- [x] 2.2 Add Anthropic/Claude Code configuration template
- [x] 2.3 Add environment variable export template
- [x] 2.4 Add usage example for Python/Node.js integration

## 3. Output Formats
- [x] 3.1 Implement human-readable output (formatted text)
- [x] 3.2 Implement JSON output (`--json` flag)
- [x] 3.3 Implement single-field output for scripting (`--endpoint`, `--port`, etc.)

## 4. Help & Documentation
- [x] 4.1 Update `show_help()` in `bin/llm-cli` to include `info` command
- [x] 4.2 Add `-h/--help` handling in `cmd_info()`
- [x] 4.3 Test help output

## 5. Testing & Validation
- [x] 5.1 Manual test: Check endpoint detection (local server running)
- [x] 5.2 Manual test: Check endpoint detection (server not running)
- [x] 5.3 Manual test: Verify JSON output validity
- [x] 5.4 Manual test: Test each configuration template
- [x] 5.5 Ensure Bash 3.2 compatibility
