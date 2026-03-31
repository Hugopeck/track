---
title: "Track PR Instructions for AI Agents"
status: approved
created: 2026-03-31
updated: 2026-03-31
---

## Track PR Instructions

Use this when opening or updating a PR in a repo with `.track/`.
Goal: link the PR to the right task, keep task status in sync, and avoid overlapping work.

---

## 1. Preflight

1. Run `bash .track/scripts/track-validate.sh`.
2. Review the current diff with `git diff HEAD`.
3. Check `.track/tasks/*.md` for tasks whose `files:` globs overlap the changed files.

If validation fails, stop and fix it before continuing.

---

## 2. Classify the PR

Pick exactly one:

- **TRACKED** — at least one task covers this work
- **UNTRACKED** — no task covers this work

Do not use a third category.

---

## 3. If TRACKED: choose the task

1. Pick one **primary task** whose `files:` scope best matches most of the diff.
2. Optional: add up to 2 `Also-Completed` tasks, but only if they are fully resolved.
3. Read the task's `## Context` and `## Acceptance Criteria`.
4. Verify each acceptance criterion with evidence. If you cannot verify one, leave it unresolved.

Do not mark partially addressed work as `Also-Completed`.

---

## 4. Sync task status with PR state

Before opening or updating the PR:

- Draft PR → set task `status: active`
- Ready-for-review PR → set task `status: review`
- Update `updated:` to today's date

Track's generated views use the open PR plus the task file together. If they drift, status will look wrong.

---

## 5. Write commit messages

Use conventional commits:

```text
type(scope): description
```

Default allowed types:

- `feat`
- `fix`
- `docs`
- `refactor`
- `test`
- `ci`
- `chore`
- `perf`
- `style`
- `build`
- `revert`

Repo-local overrides may exist in `.track/config.yml` under `commit_types:`.

Use a real subsystem for `scope`, such as `init`, `skills`, `scripts`, `tests`, `docs`, or `ci`.

BAD: `Update stuff`
BAD: `feat: add task support`
GOOD: `feat(validate): [1.4] configurable commit types in conventional-commit-lint`

`Co-Authored-By` lines are optional. Track does not require them.

---

## 6. Create the PR

Push the branch, then create the PR.

Prefer a conventional-commit PR title that includes the task ID:

```text
type(scope): [task-id] short description
```

Example:

```text
fix(validate): [8.2] correct scope matching for nested globs
```

### Body rules

- If the branch is **not** named `task/{id}-{slug}`, line 1 of the body must be `Track-Task: {id}`.
- If the branch **is** named `task/{id}-{slug}`, Track can resolve from the branch name, but adding `Track-Task:` is still preferred.
- Use at most one `Track-Task:` line.
- Add `Also-Completed:` only for tasks that are fully complete.

Tracked template:

```text
Track-Task: 8.2
Also-Completed: 8.1

## Summary
One short paragraph covering the full PR diff.

## Test plan
- [ ] Specific verification step
- [ ] Another verification step
```

Untracked template:

```text
untracked task

## Summary
One short paragraph covering the full PR diff.

## Test plan
- [ ] Specific verification step
```

---

## 7. After PR creation

Run:

```bash
bash .track/scripts/track-todo.sh --local --offline
```

Confirm the task shows the expected effective status.
