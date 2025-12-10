## 1. Pre-commit Configuration
- [x] 1.1 Create `.pre-commit-config.yaml` with ShellCheck and shfmt hooks
- [x] 1.2 Create `.shellcheckrc` for project-specific ShellCheck settings
- [x] 1.3 Create `.editorconfig` for consistent editor settings (optional)

## 2. Initial Code Formatting
- [x] 2.1 Run `shfmt -w -i 4 bin/llm-cli lib/*.sh` to format all scripts
- [x] 2.2 Run `shellcheck bin/llm-cli lib/*.sh` and fix any critical issues
- [x] 2.3 Commit formatted code as a single "Format shell scripts" commit

## 3. GitHub Actions Workflow
- [x] 3.1 Create `.github/workflows/qa.yml` with format, lint, and security checks
- [x] 3.2 Configure workflow to run on push to main and on pull requests
- [ ] 3.3 Test workflow by pushing to a branch or creating a test PR

## 4. Documentation
- [x] 4.1 Update README.md with "Contributing" or "Development" section
- [x] 4.2 Document pre-commit installation: `pip install pre-commit && pre-commit install`
- [x] 4.3 Document how to run checks manually: `pre-commit run --all-files`

## 5. Validation
- [x] 5.1 Verify pre-commit hooks work locally (make intentional error, confirm block)
- [ ] 5.2 Verify GitHub Actions workflow passes on clean code
- [ ] 5.3 Verify workflow fails and reports errors on bad code
