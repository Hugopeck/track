---
title: "Track PR Instructions for AI Agents"
status: approved
created: 2026-03-31
updated: 2026-03-31
---

## Track PR Instructions

**Read before writing anything:**
1. Run `bash .track/scripts/track-validate.sh` — fix any errors before continuing.
2. Run `git diff HEAD` and `mcp__conductor__GetWorkspaceDiff` — understand all changes.
3. Scan `.track/tasks/*.md` for tasks whose `files:` globs overlap the changed files.

---

**Step 1 — Classify the PR. Pick exactly one:**

- **TRACKED** — at least one `.track/` task directly covers these changes
- **UNTRACKED** — no task covers this work (dogfooding, hotfix, infra chore)

Do not proceed without committing to one of these. No "maybe" bucket.

---

**Step 2 — If TRACKED: identify the primary task**

- The primary task is the one whose `files:` scope best matches the bulk of changes.
- If multiple tasks qualify, pick the one with the highest priority. Note the others as `Also-Completed` candidates (max 2, only if fully resolved).
- Read `## Context` and `## Acceptance Criteria` in the task file. Verify every criterion is met — cite the file and line, or flag as unverified. Do not claim "criteria met" without evidence.

---

**Step 3 — Set task status before committing**

- Opening a **draft PR** → set `status: active` in the task file
- Opening a **ready-for-review PR** → set `status: review` in the task file
- CI enforces this match. Wrong status = failing check.
- Update `updated:` to today's date.
- Commit the task file update as the first commit, or include it in the final commit.

---

**Step 4 — Write the commit message(s)**

Required format (CI enforces):
```
type(scope): description

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

| type | when |
|------|------|
| `feat` | new user-facing capability |
| `fix` | bug fix |
| `docs` | documentation only |
| `ci` | CI/workflow changes |
| `chore` | maintenance, deps, config |
| `test` | tests only |
| `refactor` | no behavior change |
| `perf` | performance improvement |
| `style` | formatting, whitespace (no logic change) |
| `build` | build system or dependency changes |
| `revert` | reverts a previous commit |

Override per-repo via `.track/config.yml` `commit_types` list.

Scope = directory or subsystem (`init`, `scripts`, `skills`, `tests`, `ci`).

BAD: `"Update stuff"` — missing type prefix, CI rejects it
BAD: `"feat: add task support"` — vague, no scope
GOOD: `"feat(scripts): [7.4] support explicit multi-task PR batching"`

---

**Step 5 — Push and create the PR**

Push the branch, then run `gh pr create --base main`.

**Title format** (under 80 chars, CI-enforced conventional commit):
```
type(scope): [task-id] short description
```

BAD: `"Add thing"` — no type, no task ID
GOOD: `"fix(validate): [8.2] correct scope matching for nested globs"`

**Body format:**

If branch is named `task/{id}-{slug}` — CI resolves the task from branch name, no header needed. Still recommended to add `Track-Task:` for clarity.

If branch is NOT a task branch — `Track-Task: {id}` MUST be on line 1 of the body.

```
Track-Task: 8.2
Also-Completed: 8.1

## Summary
One paragraph. What changed and why. All changes in the workspace diff, not just this session.

## Test plan
- [ ] Specific thing to verify
- [ ] Another thing
```

If UNTRACKED:
```
untracked task

## Summary
...

## Test plan
...
```

**Never:**
- Multiple `Track-Task:` lines
- `Also-Completed` for partially addressed work
- Claiming task complete without verifying acceptance criteria

---

**Step 6 — After PR is created**

Run `bash .track/scripts/track-todo.sh --local --offline` and confirm the task shows the correct effective status in the output.
