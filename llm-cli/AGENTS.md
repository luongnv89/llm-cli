<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# llm-cli Agent Guidelines

## Quick Reference

| Task | Location |
|------|----------|
| Add command | `lib/*.sh` + `bin/llm-cli` dispatcher |
| Platform code | Use `case "$PLATFORM"` pattern |
| Config defaults | `lib/config.sh:get_platform_defaults()` |
| System info | `lib/benchmark.sh:get_system_info()` |
| Dependencies | `lib/utils.sh:check_dependencies()` |

## Critical Constraints

1. **Bash 3.2 Compatible** - No `declare -A` (associative arrays)
2. **Quote Variables** - Always `"$var"` not `$var`
3. **Cross-Platform** - Test macOS, linux-nvidia, linux-cpu paths
4. **XDG Compliant** - Use standard directories for config/data/cache

## Supported Platforms

| Platform | Detection | GPU Backend |
|----------|-----------|-------------|
| `macos` | `uname -s == Darwin` | Metal |
| `linux-nvidia` | `nvidia-smi` available | CUDA |
| `linux-cpu` | Linux without nvidia-smi | None |

## File Locations

- **Config**: `~/.config/llm-cli/config`
- **Data**: `~/.local/share/llm-cli/`
- **Cache**: `~/.cache/llm-cli/`
- **Models**: `~/.cache/huggingface/hub/`

## Before Making Changes

1. Read `openspec/project.md` for full conventions
2. Run `shellcheck` on modified files
3. Test platform detection: `./bin/llm-cli --platform <name> config`
4. Do NOT commit without user request
