# Change: Add DevOps Quality Assurance Pipeline

## Why
The project currently has no automated quality checks. Without pre-commit hooks or CI/CD workflows, code style inconsistencies, shell script errors, and potential security issues can slip into the repository undetected. Adding automated quality assurance will:
- Enforce consistent code style across all shell scripts
- Catch common shell scripting errors before they reach the repository
- Identify potential security vulnerabilities early
- Provide confidence that all changes pass quality gates

## What Changes
- Add a `pre-commit` hook configuration to run format, lint, and security checks locally before commits
- Create GitHub Actions workflow to run the same checks on push/pull request
- Add configuration files for linting and formatting tools
- All tools selected are open-source and free (no paid services)

## Impact
- Affected specs: `devops-qa` (new capability)
- Affected code:
  - `.pre-commit-config.yaml` (new)
  - `.github/workflows/qa.yml` (new)
  - `.shellcheckrc` (new, optional configuration)
  - `.editorconfig` (new, optional for consistent formatting)
- Developer workflow: Contributors must install `pre-commit` and run `pre-commit install` once
