## Context
This is a Bash-based CLI project targeting macOS with Apple Silicon. The project has 8 shell scripts (1 entry point + 7 library modules). All tools must be:
- Open-source and free
- Compatible with macOS and Linux (for CI)
- Suitable for shell script analysis

## Goals / Non-Goals
- **Goals:**
  - Automate format, lint, and security checks
  - Run checks locally (pre-commit) and in CI (GitHub Actions)
  - Minimal configuration, low maintenance
  - Fast feedback loop for developers

- **Non-Goals:**
  - Full test automation (the project relies on manual testing)
  - Deployment pipelines
  - Code coverage metrics

## Decisions

### Tool Selection

| Check Type | Tool | Rationale |
|------------|------|-----------|
| **Linting** | [ShellCheck](https://github.com/koalaman/shellcheck) | Industry-standard static analysis for shell scripts. Catches bugs, deprecations, and portability issues. Free, open-source, available via brew/apt. |
| **Formatting** | [shfmt](https://github.com/mvdan/sh) | Fast shell formatter. Enforces consistent style. Free, open-source, available via brew/apt. |
| **Security** | ShellCheck (built-in) | ShellCheck includes security-related warnings (SC2086, SC2091, etc.). Additional: [git-secrets](https://github.com/awslabs/git-secrets) for credential scanning (optional). |
| **Pre-commit Framework** | [pre-commit](https://pre-commit.com/) | Language-agnostic hook manager. Widely adopted, free, supports all our tools natively. |

### Why These Tools?
1. **ShellCheck**: Most mature shell linter, catches 300+ types of issues, works with Bash 3.2
2. **shfmt**: Only serious shell formatter, can enforce POSIX or Bash styles
3. **pre-commit**: Handles hook installation, caching, and multi-language support automatically
4. **GitHub Actions**: Free for public repos, well-integrated, large ecosystem

### Configuration Choices
- **shfmt style**: Use `-i 4` (4-space indent) to match existing code, `-bn` for binary ops at start of line
- **ShellCheck severity**: Enable all checks (default), use `.shellcheckrc` for project-specific exclusions if needed
- **pre-commit hooks**: Run on all `.sh` files and `bin/llm-cli`

## Alternatives Considered

| Alternative | Why Not Chosen |
|-------------|----------------|
| Husky (Node.js) | Adds Node.js dependency to a pure Bash project |
| GitHub Super-Linter | Heavy (Docker-based), slower, overkill for shell-only project |
| Lefthook | Good but pre-commit has better shell tool support |
| Manual git hooks | No caching, harder to maintain, not portable |

## Risks / Trade-offs
- **Risk**: Developers must install pre-commit locally
  - **Mitigation**: Document setup in README, CI catches if hooks bypassed
- **Risk**: False positives from ShellCheck
  - **Mitigation**: Use `.shellcheckrc` to disable specific checks with comments explaining why
- **Risk**: shfmt may format differently than existing style
  - **Mitigation**: Run initial format, review changes, adjust config if needed

## Migration Plan
1. Add tool configurations (`.pre-commit-config.yaml`, `.shellcheckrc`)
2. Run `shfmt` on all files, commit reformatted code as single commit
3. Add GitHub Actions workflow
4. Update README with contributor setup instructions
5. Enable branch protection (optional, manual step)

## Open Questions
- Should we require `pre-commit install` in `install.sh` for developers? (Recommend: no, keep install.sh for end users only)
- Desired shfmt indent width? (Recommend: 4 spaces based on existing code inspection)
