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

`/track:validate` owns the validation-and-fix loop — running `track-validate.sh`,
interpreting errors, guiding the user to fixes, and re-running until clean.

## What This Skill Owns

1. Run `bash scripts/track-validate.sh`
2. Interpret every error in plain language
3. Suggest the exact fix for each error
4. Offer to re-run after fixes are applied

This skill does NOT own applying fixes — it has no Edit or Write access. It
diagnoses and prescribes; the user or another skill applies.

## Definition of Done

- Validation passes, or all errors are explained with actionable fixes and the
  user has been offered a re-run

## Steps

1. Run `bash scripts/track-validate.sh`
2. If validation passes, show the closing message
3. If validation fails, for each error:
   - Read the offending task or project file
   - Explain what's wrong in plain language
   - Suggest the specific fix (which field to change, what value to use)
4. After the user applies fixes, offer to re-run validation

## Interpreting Results

Each error message includes the exact fix needed — read it carefully and apply
directly.

**Patterns to watch for:**
- Multiple `unknown project_id` errors usually mean the project brief wasn't
  created first
- Multiple `missing required field` errors on the same file suggest it was created
  outside Track's conventions — compare against the task format in `/track:work`
- Dependency errors (`depends on non-done task`) often indicate work started out
  of order — check whether the dependency is actually needed or can be removed

## Closing Message

On pass:

```
Validation passed: N tasks (X todo, Y active, Z done).
```

On fail:

```
Validation failed with {N} errors. Fixes listed above.
Re-run /track:validate after applying fixes.
```

## Do Not

- Do not report success if validation failed
- Do not skip reading the offending file before suggesting a fix
