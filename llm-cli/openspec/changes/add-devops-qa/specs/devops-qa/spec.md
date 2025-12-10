## ADDED Requirements

### Requirement: Pre-commit Hook Configuration
The project SHALL provide a pre-commit configuration that runs quality checks before commits are created.

#### Scenario: Developer installs pre-commit hooks
- **WHEN** a developer runs `pre-commit install` in the repository
- **THEN** git hooks are installed that will run quality checks on staged files before each commit

#### Scenario: Pre-commit blocks commit with linting errors
- **WHEN** a developer attempts to commit a shell script with ShellCheck errors
- **THEN** the commit is blocked and error details are displayed

#### Scenario: Pre-commit blocks commit with formatting issues
- **WHEN** a developer attempts to commit a shell script that is not properly formatted
- **THEN** the commit is blocked and the file is auto-formatted (or diff is shown)

### Requirement: Shell Script Linting
The project SHALL use ShellCheck to analyze all shell scripts for errors, warnings, and style issues.

#### Scenario: ShellCheck runs on all shell files
- **WHEN** quality checks are executed
- **THEN** ShellCheck analyzes `bin/llm-cli` and all `.sh` files in `lib/`

#### Scenario: ShellCheck respects project configuration
- **WHEN** ShellCheck runs
- **THEN** it reads settings from `.shellcheckrc` if present

### Requirement: Shell Script Formatting
The project SHALL use shfmt to enforce consistent formatting across all shell scripts.

#### Scenario: shfmt validates formatting
- **WHEN** quality checks are executed
- **THEN** shfmt checks that all shell scripts follow the configured style

#### Scenario: shfmt uses project conventions
- **WHEN** shfmt runs
- **THEN** it uses 4-space indentation to match existing code style

### Requirement: GitHub Actions CI Workflow
The project SHALL provide a GitHub Actions workflow that runs quality checks on push and pull request events.

#### Scenario: CI runs on push to main
- **WHEN** code is pushed to the main branch
- **THEN** the QA workflow runs format, lint, and security checks

#### Scenario: CI runs on pull request
- **WHEN** a pull request is opened or updated
- **THEN** the QA workflow runs and reports status on the PR

#### Scenario: CI fails on quality issues
- **WHEN** the CI workflow detects linting errors or formatting issues
- **THEN** the workflow fails with a non-zero exit code and displays error details

### Requirement: Security Scanning
The project SHALL include basic security scanning to detect potential vulnerabilities in shell scripts.

#### Scenario: ShellCheck security warnings are enabled
- **WHEN** ShellCheck runs
- **THEN** security-related checks (command injection, unquoted variables, etc.) are enabled

#### Scenario: CI detects hardcoded secrets
- **WHEN** a file containing potential secrets (API keys, passwords) is committed
- **THEN** the check warns or fails (depending on configuration)
