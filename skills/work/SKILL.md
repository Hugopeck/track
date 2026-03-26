---
name: work
description: |
  Track's operating protocol. You are a disciplined engineer who reads state
  before acting, maintains context for future sessions, and lets the PR
  lifecycle drive status. Loaded automatically in any repo with .track/.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

## Purpose

`/track:work` owns the full work-a-task lifecycle — from reading state through
implementation to handing off to merge. It is loaded automatically in any repo
that contains `.track/`.

## What This Skill Owns

1. Read current Track state (tasks, projects, plans)
2. Determine the operating mode
3. Pick or resume a task
4. Open a draft PR and implement
5. Mark the PR ready for review
6. Hand off to the post-merge workflow

If the user invoked `/track:work` or asked to work a task, your job is to
complete this lifecycle for one task.

## Operating Modes

Track one of these modes for the entire run:

- `pick` — no task was specified, find the next available task
- `resume` — a task was specified by the user or an active plan was found,
  continue existing work
- `empty` — no open tasks exist (all `done`, `cancelled`, or `.track/tasks/`
  is empty)

## Definition of Done

- `pick` is done when a draft PR is opened and implementation is underway
- `resume` is done when the session's work is committed and pushed
- `empty` is done when the user is informed and given next steps

Do not report a task as "started" before a draft PR exists. Do not report
success before the mode reaches its definition of done.

## Glossary

- **Raw Status** — the `status:` field stored in a Track task file
- **Effective Status** — derived from raw status plus live open PR state; what `TODO.md` shows
- **Provisional PR** — an implementation PR opened as soon as work starts on a task; draft = active, ready-for-review = review
- **Project Brief** — a markdown scope contract in `.track/projects/{project_id}-{slug}.md`
- **Task** — a Track work item at `.track/tasks/{task_id}-{slug}.md` with YAML frontmatter and required body sections
- **View / Pointer** — a non-canonical navigation surface; `TODO.md` is the primary Track view

## Working Philosophy

Track coordinates work across sessions and agents. These principles make coordination reliable:

- **Context is perishable.** Every session starts cold. The task file's `## Notes` section is your memory. Write down discoveries, dead ends, design decisions, and open questions as you encounter them — not at the end of a session.
- **Small beats comprehensive.** A task that ships a focused change and merges is worth more than a task that attempts a complete rewrite and stalls. If you realize a task is larger than expected, split it.
- **Dependencies are contracts.** When task A depends on task B, A cannot start until B is done. Be conservative adding dependencies — they serialize work. Be precise about what the dependency actually provides.
- **File scopes prevent collisions.** The `files:` field isn't documentation — it's a coordination mechanism. Two active tasks with overlapping file scopes will produce merge conflicts. Treat `files:` as a mutex.
- **The PR is the proof.** Don't describe what you'll do — open a draft PR and show what you're doing. The provisional PR lifecycle makes progress visible without status updates.

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
2. Check for active plans — scan `.track/plans/*.md` for plan files. If a plan exists
   with `Status: approved` and its linked tasks are not all `done`:
   - Read the plan file
   - Tell the user: "Found an active plan: {title}. The next task is {task_id}: {title}."
   - Suggest working that task
3. Check `files:` globs against tasks already shown as `active` / `review` — avoid overlap
4. Pick work that has no unresolved `depends_on` blockers
5. Read the task's `## Context` and `## Notes` — previous sessions may have left important context
6. If the task's mode is `investigate`, focus on understanding and documenting findings rather than writing code
7. If the acceptance criteria seem incomplete or unclear, update them before starting implementation
8. Use a dedicated worktree or branch per task
9. If no open tasks exist (all tasks are `done` or `cancelled`, or `.track/tasks/` is
   empty), set mode to `empty`

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

## When to Split a Task

Split a task when any of these are true:
- The PR will touch more than 500 lines across more than 3 unrelated files
- You discover a prerequisite that wasn't in the original plan
- The acceptance criteria have grown beyond the original scope
- Two logically independent changes are bundled together

To split: create new task(s) with proper `depends_on`, update the original task's acceptance criteria to reflect the reduced scope, and add a note explaining the split.

## Regenerating TODO.md

After creating, updating, cancelling, or completing tasks:

```shell
bash .track/scripts/track-todo.sh            # default: origin/main + live PR data
bash .track/scripts/track-todo.sh --local    # local working tree
bash .track/scripts/track-todo.sh --offline  # skip GitHub PR lookup
```

## Validation

After changing task files, project briefs, or scripts:

```shell
bash .track/scripts/track-validate.sh
```

Always validate after creating or modifying tasks. Fix any errors before committing.

## Overlap Detection

The `files:` field on tasks declares which files a task expects to touch. Two tasks
with overlapping `files:` globs should not both be `active` at the same time — this
causes merge conflicts. Before starting a task, check that its `files:` don't overlap
with any currently `active` or `review` task.

## Closing Message Matrix

When a work session concludes, show exactly one closing message:

If mode is `pick` and a draft PR was opened:

```
Started task {id}: {title}
Draft PR: {url}

Implementation is underway. Continue working or mark ready for review when done.
```

If mode is `resume` and work was pushed:

```
Resumed task {id}: {title}
Pushed {N} commits to {branch}.

Continue working or mark ready for review when done.
```

If mode is `empty`:

```
No open tasks. Use /track:create to add a task, or /track:decompose to break
a goal into tasks.
```

## Do Not

- Do not edit `TODO.md` by hand — it is generated and will be overwritten
- Do not set `status: done` manually — the post-merge workflow handles this
- Do not create tasks without a matching project brief
- Do not use the same `files:` glob as an already-active task
- Do not skip reading `## Notes` and `## Context` before starting work
- Do not report a task as started without opening a draft PR
- Do not work a task whose `depends_on` has unresolved blockers
- Do not report success before the active mode reaches its definition of done
