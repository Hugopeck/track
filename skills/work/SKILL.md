---
name: work
description: |
  Core Track workflow protocol. Teaches how to read task state, pick work,
  start tasks, manage PR lifecycle, validate, and regenerate TODO.md. Use when
  working in any repo that has a .track/ directory.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

## Glossary

- **Raw Status** — the `status:` field stored in a Track task file
- **Effective Status** — derived from raw status plus live open PR state; what `TODO.md` shows
- **Provisional PR** — an implementation PR opened as soon as work starts on a task; draft = active, ready-for-review = review
- **Project Brief** — a markdown scope contract in `.track/projects/{project_id}-{slug}.md`
- **Task** — a Track work item at `.track/tasks/{task_id}-{slug}.md` with YAML frontmatter and required body sections
- **View / Pointer** — a non-canonical navigation surface; `TODO.md` is the primary Track view

## Layout

```
.track/
  projects/       # scope contracts — one per initiative
    {project_id}-{slug}.md
  tasks/           # flat task files — one per unit of work
    {task_id}-{slug}.md
```

`TODO.md` is generated and gitignored. It is never canonical state.

## Task File Format

```yaml
---
id: "{project_id}.{task_id}"
title: "One-line objective"
status: todo
mode: implement
priority: high
project_id: "{project_id}"
created: YYYY-MM-DD
updated: YYYY-MM-DD
depends_on: []
files: []
pr: ""
---

## Context
What needs to happen and why.

## Acceptance Criteria
- [ ] Primary outcome

## Notes
Append-only log.
```

### Fields

| Field | Values | Purpose |
|-------|--------|---------|
| `id` | `{project}.{task}` | Unique identifier. Number before dot must match `project_id`. |
| `title` | Free text | One-line objective. |
| `status` | `todo`, `active`, `review`, `done`, `cancelled` | Lifecycle position. |
| `mode` | `investigate`, `plan`, `implement` | What kind of work. |
| `priority` | `urgent`, `high`, `medium`, `low` | Relative importance. |
| `project_id` | Number string | Must match a brief in `projects/`. |
| `depends_on` | List of task IDs | Must be `done` before this task can start. |
| `files` | List of glob patterns | Files this task expects to touch. Used for overlap detection. |
| `pr` | URL string | Populated when completed via merged PR. |
| `cancelled_reason` | Free text | Required when `status: cancelled`. |

## Raw vs Effective Status

1. If raw status is `done` or `cancelled` → effective status matches (terminal)
2. If there's an open **draft** PR on `task/{id}-{slug}` → effective = `active`
3. If there's an open **ready-for-review** PR → effective = `review`
4. Otherwise → effective = `todo`

You don't manually set `status: active` to show progress — opening a draft PR does it automatically.

## Before Starting Work

1. Read `TODO.md` or scan `.track/tasks/*.md` for available work
2. Check `files:` globs against tasks already shown as `active` / `review` — avoid overlap
3. Pick work that has no unresolved `depends_on` blockers
4. Use a dedicated worktree or branch per task

## Working a Task (Provisional PR Lifecycle)

1. Create branch `task/{id}-{slug}` from the default branch
2. First commit updates the task file only:
   - set raw `status: active`
   - update `updated:` to today
3. Push and open a **draft PR** immediately
   - PR title must include the task ID: `[{id}] Title` or `({id}) Title`
   - CI will lint the branch name and PR title
4. Do the implementation work with as many commits as needed
5. When ready for review:
   - set raw `status: review`
   - update `updated:`
   - mark the PR ready for review
6. When the PR merges, the post-merge workflow writes `status: done`, `pr:`, and `updated:` on the default branch

## Creating a Task

- Every task belongs to a project via `project_id`
- Use dotted IDs: `{project_id}.{sequence}` (e.g., `1.1`, `1.2`, `2.1`)
- To find the next ID: scan `.track/tasks/` for the highest sequence number under that project
- Put scope and success definition in the project brief, not the task

## Decomposing a Goal

- Analyze module boundaries first
- Create one task per independent unit with non-overlapping `files:` scopes
- Use `depends_on` to sequence foundation work before integration work
- Prefer small reviewable PRs over multi-goal tasks

## Regenerating TODO.md

After creating, updating, cancelling, or completing tasks:

```shell
bash scripts/track-todo.sh            # default: origin/main + live PR data
bash scripts/track-todo.sh --local    # local working tree
bash scripts/track-todo.sh --offline  # skip GitHub PR lookup
```

## Validation

After changing task files, project briefs, or scripts:

```shell
bash scripts/track-validate.sh
```

Always validate after creating or modifying tasks. Fix any errors before committing.

## Overlap Detection

The `files:` field on tasks declares which files a task expects to touch. Two tasks
with overlapping `files:` globs should not both be `active` at the same time — this
causes merge conflicts. Before starting a task, check that its `files:` don't overlap
with any currently `active` or `review` task.

## What Not To Do

- Do not edit `TODO.md` by hand — it is generated and will be overwritten
- Do not set `status: done` manually — the post-merge workflow handles this
- Do not create tasks without a matching project brief
- Do not use the same `files:` glob as an already-active task
