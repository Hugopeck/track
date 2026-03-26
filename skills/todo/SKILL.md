---
name: todo
description: |
  Regenerate the shared coordination view. Detect the best mode based on
  environment (full, local, or offline), run track-todo.sh, and report what
  changed. TODO.md is the team's window into current state.
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
---

## Purpose

`/track:todo` owns TODO.md regeneration — detecting the environment, choosing
the right mode, running `track-todo.sh`, and reporting the result.

## What This Skill Owns

1. Detect the available environment
2. Choose the generation mode
3. Run `bash .track/scripts/track-todo.sh` with appropriate flags
4. Report the result

This skill does NOT own interpreting TODO.md content or acting on it.

## Definition of Done

- `TODO.md` is regenerated and the mode used is reported to the user

## Steps

1. Detect available environment:
   - Check if `gh` command exists
   - Check if `GH_TOKEN` or `GITHUB_TOKEN` is set
   - Check if `origin/main` (or the configured default branch) is reachable
2. Choose mode:
   - If `gh` available and token set and remote reachable → full mode (no flags)
   - If remote reachable but no `gh` or token → `--offline`
   - If remote not reachable → `--local --offline`
3. Run `bash .track/scripts/track-todo.sh {flags}`
4. Show the closing message

If the user passes arguments (e.g., `/track:todo --local`), forward those flags
directly instead of auto-detecting.

## Closing Message

```
TODO.md regenerated (mode: {full|offline|local}).
```

## Do Not

- Do not edit TODO.md by hand — it is generated
- Do not override user-supplied flags with auto-detection
