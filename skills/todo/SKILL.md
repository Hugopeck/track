---
name: todo
description: |
  Regenerate TODO.md from .track/ state and live PR metadata. Detects the best
  mode (full, local, or offline) based on environment availability.
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
---

## Purpose

Regenerate `TODO.md` by running `track-todo.sh` with the appropriate mode.

## Steps

1. Detect available environment:
   - Check if `gh` command exists
   - Check if `GH_TOKEN` or `GITHUB_TOKEN` is set
   - Check if `origin/main` (or the configured default branch) is reachable
2. Choose mode:
   - If `gh` available and token set and remote reachable → full mode (no flags)
   - If remote reachable but no `gh` or token → `--offline`
   - If remote not reachable → `--local --offline`
3. Run `bash scripts/track-todo.sh {flags}`
4. Report what was generated and which mode was used

If the user passes arguments (e.g., `/track:todo --local`), forward those flags directly instead of auto-detecting.
