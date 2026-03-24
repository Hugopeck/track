---
name: validate
description: |
  Run Track validation and interpret errors. Executes track-validate.sh, reads
  any failing task files, and suggests fixes.
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

## Common Errors and Fixes

| Error | Fix |
|-------|-----|
| `missing required field 'X'` | Add the field to frontmatter |
| `invalid status 'X'` | Use one of: `todo`, `active`, `review`, `done`, `cancelled` |
| `invalid mode 'X'` | Use one of: `investigate`, `plan`, `implement` |
| `unknown project_id 'X'` | Create a matching project brief or fix the ID |
| `dotted id must match project_id` | Ensure the number before the dot matches `project_id` |
| `cancelled tasks require cancelled_reason` | Add `cancelled_reason:` field |
| `depends_on references missing task` | Fix the dependency ID or remove it |
| `active/review task depends on non-done task` | Complete the dependency first or change status |
| `missing required section` | Add `## Context`, `## Acceptance Criteria`, or `## Notes` |
