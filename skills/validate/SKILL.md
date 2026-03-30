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
The canonical runtime source for that script lives at
`skills/validate/scripts/track-validate.sh`; `/track:init` installs it into the
adopting repo at `.track/scripts/track-validate.sh`.

## What This Skill Owns

1. Run `bash .track/scripts/track-validate.sh`
2. Interpret every error in plain language
3. Suggest the exact fix for each error
4. Offer to re-run after fixes are applied

This skill does NOT own applying fixes — it has no Edit or Write access. It
diagnoses and prescribes; the user or another skill applies.

## Definition of Done

- Validation passes, or all errors are explained with actionable fixes and the
  user has been offered a re-run

## Steps

1. Run `bash .track/scripts/track-validate.sh`.
   If the script is not found, STOP: "Validation script missing at
   `.track/scripts/track-validate.sh`. Run `/track:init` to install it."
2. If validation passes, show the closing message
3. If validation fails, for each error:
   - Read the offending task or project file
   - Explain what's wrong using this format:
     ```
     [ERROR] .track/tasks/1.3-foo.md: depends_on references "1.1" which has
     status: cancelled. Fix: remove "1.1" from depends_on, or reopen task 1.1.
     ```
   - BAD error explanation: "There are some issues with the task file." —
     too vague, name the exact field and the exact fix.
   - GOOD error explanation: "task 1.3: `project_id` is `"2"` but no project
     brief exists at `.track/projects/2-*.md`. Fix: create the project first
     with `/track:create project: {name}`, or change `project_id` to `"1"`."
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
- Do not give vague explanations — name the exact field, the exact problem, and the exact fix
- Do not suggest a fix without reading the file first — the error message alone may not tell the full story
