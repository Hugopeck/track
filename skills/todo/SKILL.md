---
name: todo
description: |
  Regenerate the shared coordination views. Detect the best mode based on
  environment (full, local, or offline), run track-todo.sh, and report what
  changed. `TODO.md` is the execution queue, `BOARD.md` is the operational map,
  and `PROJECTS.md` is the high-level summary.
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
---

## Purpose

`/track:todo` owns Track view regeneration — detecting the environment, choosing
the right mode, running `track-todo.sh`, and reporting the result. The
canonical runtime source lives at `skills/todo/scripts/track-todo.sh`;
`/track:init` installs it into the adopting repo at
`.track/scripts/track-todo.sh`.

## What This Skill Owns

1. Detect the available environment
2. Choose the generation mode
3. Run `bash .track/scripts/track-todo.sh` with appropriate flags
4. Report the result

This skill does NOT own interpreting Track view content or acting on it.

## Definition of Done

- `BOARD.md`, `TODO.md`, and `PROJECTS.md` are regenerated and the mode used is reported to the user

## Steps

1. Detect available environment:
   - Check if `gh` command exists
   - Check if `GH_TOKEN` or `GITHUB_TOKEN` is set
   - Check if `origin/main` (or the configured default branch) is reachable
2. Choose mode:
   - If `gh` available and token set and remote reachable → full mode (no flags)
   - If remote reachable but no `gh` or token → `--offline`
   - If remote not reachable → `--local --offline`
3. Run `bash .track/scripts/track-todo.sh {flags}`.
   If the script is not found, STOP: "TODO script missing at
   `.track/scripts/track-todo.sh`. Run `/track:init` to install it."
   If it exits non-zero, show the error output and suggest: "Run `/track:validate`
   to check for task file errors that may be blocking TODO generation."
4. After running, verify `BOARD.md`, `TODO.md`, and `PROJECTS.md` exist. If `TODO.md` is empty or missing, warn:
   "TODO.md is empty — this usually means no tasks exist yet."
5. Show the closing message

If the user passes arguments (e.g., `/track:todo --local`), forward those flags
directly instead of auto-detecting.

## Closing Message

```
Track views regenerated (mode: {full|offline|local}).
```

## Do Not

- Do not edit `BOARD.md`, `TODO.md`, or `PROJECTS.md` by hand — they are generated
- Do not override user-supplied flags with auto-detection
