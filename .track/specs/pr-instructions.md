---
title: "Track PR Instructions for AI Agents"
status: approved
created: 2026-03-31
updated: 2026-04-01
---

## Track PR Instructions

Use this when opening or updating a PR in a repo with `.track/`.
Goal: link the PR to the right task, let Track scripts own lifecycle status, and keep the PR mergeable under GitHub rules.

---

## 1. Preflight

1. Run `bash .track/scripts/track-validate.sh`.
2. Review the current diff with `git diff HEAD`.
3. Check `.track/tasks/*.md` for tasks whose `files:` globs overlap the changed files.
4. If the PR already exists, inspect GitHub state before changing anything:
   ```bash
   gh pr view <number> --json isDraft,mergeStateStatus,mergeable,statusCheckRollup
   ```

If validation fails, STOP and fix it before continuing.
If another active or review task owns the same files, STOP and resolve the overlap first. If the overlap comes from a task stuck in `active` or `review` after its PR already merged or closed, treat that as canonical-status drift and repair it with Track automation before continuing. Do not hand-edit another task's `files:` or status just to make the warning disappear.

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

## 4. Sync tracked status with PR state

Use Track scripts and PR lifecycle automation, not manual frontmatter edits.

- Starting tracked work locally or opening a tracked draft PR:
  ```bash
  bash .track/scripts/track-start.sh {task_id}
  ```
  This sets `status: active`, updates `updated:`, and validates.
- Ready-for-review tracked PR:
  mark the draft PR ready for review and let `track-status-sync` write `status: review`.
- Merged PRs are completed by Track automation. Do not hand-edit `status: done` on the branch.
- Untracked PRs stay untracked until one task clearly and deterministically matches.

BAD: edit `status: active` or `status: review` by hand, then create or update the PR later.
GOOD: run `track-start.sh` for tracked work, then let PR lifecycle automation handle review and later transitions.

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

Use a real subsystem for `scope`, such as `setup-track`, `skills`, `scripts`, `tests`, `docs`, or `ci`.

BAD: `Update stuff`
BAD: `feat: add task support`
GOOD: `feat(scripts): [9.2] add PR lifecycle status sync`

`Co-Authored-By` lines are optional. Track does not require them.

---

## 6. Create or update the PR

Push the branch, then create or update the PR.

Prefer a conventional-commit PR title that includes the task ID:

```text
type(scope): [task-id] short description
```

Example:

```text
fix(ci): [9.2] run required checks on PR updates
```

### Body rules

- If the branch is **not** named `task/{id}-{slug}`, line 1 of the body must be `Track-Task: {id}`.
- If the branch **is** named `task/{id}-{slug}`, Track can resolve from the branch name, but adding `Track-Task:` is still preferred.
- Use at most one `Track-Task:` line.
- Add `Also-Completed:` only for tasks that are fully complete.

Tracked template:

```text
Track-Task: 9.2
Also-Completed: 9.1

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

## 7. Keep the PR mergeable

After every push, inspect mergeability and required checks:

```bash
gh pr view <number> --json mergeStateStatus,mergeable,statusCheckRollup
```

Interpret the result conservatively:

- `mergeStateStatus: CLEAN` + required checks green → PR is mergeable
- `mergeStateStatus: BEHIND` → rebase or merge `origin/main`, then push again
- `mergeStateStatus: BLOCKED` with missing required checks → fix the workflow or wait for checks
- `mergeable: CONFLICTING` → resolve merge conflicts locally and push

Important finding: if the repo uses **strict required status checks**, a PR can be blocked even when old checks passed. The current head must be up to date with `main`, and the required check names must run on the latest commit after `synchronize`.

If required checks are `Track Validate` and `Track PR Lint`, ensure those workflows still trigger on direct PR updates, not only through `workflow_call`.

---

## 8. After PR creation or update

Run:

```bash
bash .track/scripts/track-todo.sh --local --offline
```

Then confirm all three:

1. the task file has the expected raw status (`active` for draft, `review` for ready)
2. `TODO.md` shows the expected in-progress state
3. `gh pr checks <number>` shows the required checks for the latest head commit

If any of these drift, fix the drift before asking for review or merge.
