# Track Scripts

Bash scripts that enforce Track conventions. These are managed by Track and
installed by `/track:init` — do not edit them directly. If you need to update
a script, change the canonical copy in the Track plugin and re-run init.

## Scripts

| Script | Purpose | Run by |
|--------|---------|--------|
| `track-common.sh` | Shared library — YAML parser, utilities, glob overlap detection | Sourced by other scripts |
| `track-validate.sh` | Validate all task files, project briefs, and plan expiry | CI + local |
| `track-todo.sh` | Generate `TODO.md` from tasks, projects, and PR state | CI + local |
| `track-pr-lint.sh` | Lint PR branch names and titles against task conventions | CI only |
| `track-complete.sh` | Mark a task as done after its PR merges | CI only (post-merge workflow) |

## Requirements

- **bash** 3.2+ (macOS default)
- **git**
- **gh** (GitHub CLI) — required for PR-based status detection. Run `gh auth login` to authenticate.
