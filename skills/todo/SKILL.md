---
name: refresh-track
description: |
  Regenerate Track's shared views mid-session or at any point during work.
  Detect the environment (full, local, or offline), run `track-todo.sh`, and
  report what changed in `BOARD.md`, `TODO.md`, and `PROJECTS.md`.
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
---

## Purpose

`/track:refresh-track` owns Track view regeneration — detecting the environment,
choosing the right mode, running `track-todo.sh`, and reporting the result. The
canonical runtime source lives at `skills/todo/scripts/track-todo.sh`;
`/track:setup-track` installs it into the adopting repo at
`.track/scripts/track-todo.sh`.

## What This Skill Owns

1. Detect the available environment
2. Choose the generation mode
3. Run `bash .track/scripts/track-todo.sh` with the correct flags
4. Verify the generated artifacts exist
5. Report the result

This skill does NOT own interpreting Track view content or acting on it.

## Operating Modes

Lock one mode at the start. Do not silently drift.

- `forwarded` — user supplied flags explicitly; forward them unchanged
- `full` — use remote state and live PR data
- `offline` — use remote state without GitHub API calls
- `local` — use only the local working tree

## Definition of Done

- `BOARD.md`, `TODO.md`, and `PROJECTS.md` are regenerated
- The selected mode is reported to the user
- User-supplied flags are preserved when present
- Failure paths stop with a concrete next step

## Steps

1. Detect available environment:
   - Check if `gh` exists
   - Check if `GH_TOKEN` or `GITHUB_TOKEN` is set
   - Check if `origin/main` (or the configured default branch) is reachable
2. Choose mode:
   - If the user supplied flags, lock `forwarded` and use those flags unchanged
   - If `gh` is available, a token is set, and the remote is reachable, lock `full`
   - If the remote is reachable without GitHub API access, lock `offline`
   - Otherwise, lock `local`
3. Run `bash .track/scripts/track-todo.sh {flags}`.
   - If the script is missing, STOP: `TODO script missing at .track/scripts/track-todo.sh. Run /track:setup-track to install it.`
   - If it exits non-zero, surface the error and say: `Run bash .track/scripts/track-validate.sh to check for task file errors that may be blocking view generation.`
4. Verify `BOARD.md`, `TODO.md`, and `PROJECTS.md` exist.
   - If `TODO.md` is empty or missing, warn: `TODO.md is empty — this usually means no tasks exist yet.`
5. Emit the closing message from the matrix.

If the user passes arguments (example: `/track:refresh-track --local --offline`),
forward those flags directly instead of auto-detecting.

## Closing Message Matrix

- `full` → `Track views regenerated (mode: full).`
- `offline` → `Track views regenerated (mode: offline).`
- `local` → `Track views regenerated (mode: local).`
- `forwarded` → `Track views regenerated (mode: {resolved_mode}).`

## Do Not

- Do not edit `BOARD.md`, `TODO.md`, or `PROJECTS.md` by hand
- Do not override user-supplied flags with auto-detection
- Do not interpret or summarize task state beyond confirming regeneration
