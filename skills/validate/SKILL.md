---
name: validate
description: |
  Run validation and make it self-correcting. Execute track-validate.sh, read any
  failing files, explain what went wrong in plain language, and suggest the exact
  fix. Every error should lead directly to a resolution.
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

## Purpose

Run `track-validate.sh` and help the user fix any validation errors.

## Steps

1. Run `bash scripts/track-validate.sh`
2. If validation passes, report success
3. If validation fails, for each error:
   - Read the offending task file
   - Explain what's wrong in plain language
   - Suggest the specific fix (which field to change, what value to use)
4. After the user applies fixes, offer to re-run validation

## Interpreting Results

Each error message now includes the exact fix needed — read it carefully and apply directly.

**Patterns to watch for:**
- Multiple `unknown project_id` errors usually mean the project brief wasn't created first
- Multiple `missing required field` errors on the same file suggest it was created outside Track's conventions — compare against the task format in `/track:work`
- Dependency errors (`depends on non-done task`) often indicate work started out of order — check whether the dependency is actually needed or can be removed

When validation passes, it reports a summary of task counts by status — use this to confirm the state looks right.
