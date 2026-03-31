---
name: work
description: |
  Track's operating protocol. You are a disciplined engineer who reads state
  before acting, maintains context for future sessions, and lets the PR
  lifecycle drive status. Loaded automatically in any repo with .track/.
  Also handles quick operations: linking branches to tasks for attribution,
  and appending context notes to task files.
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

## Role

This skill is the fallback protocol. In repos with a complete Track section in CLAUDE.md, that section is primary. This skill activates when the CLAUDE.md section is missing or incomplete, or when invoked directly.

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

Lock one of these modes at the start and do not switch mid-run:

- `pick` — no task was specified, find the next available task
- `resume` — a task was specified by the user or an active plan was found,
  continue existing work
- `empty` — no open tasks exist (all `done`, `cancelled`, or `.track/tasks/`
  is empty)

If `pick` discovers an in-progress task (existing branch or draft PR), that is a
`resume` — acknowledge the switch explicitly in output before continuing.

## Quick Operations

Some user requests are atomic actions, not work sessions. Detect these before
locking a mode — handle them immediately and exit.

### `link` — retroactive branch attribution

When the user says "link this branch to task X" or "attribute this work to X":

1. Extract the task ID from user input.
2. Validate the task exists in `.track/tasks/`. If not, STOP: "Task {id} not found."
3. Ensure `.track/events/` directory exists — create it if missing.
4. Resolve repo metadata: repo root, current branch, UTC timestamp, repo identifier
   (from `git remote get-url origin`, same resolution as the post-commit hook).
5. Append one JSONL line to `.track/events/log.jsonl`:
   ```json
   {"type":"track.link","version":"1","timestamp":"...","repo":"...","branch":"...","task_id":"...","link_mode":"branch_history"}
   ```
6. Respond: "Linked branch {branch} to task {id}."

`link` is complete only after the JSONL line is appended successfully.

Do not open a PR, change task status, or lock a mode.

### `context` — append to task notes

When the user says "add context to task X", "note that...", or "update notes on X":

1. Extract the task ID and content from user input.
2. Read the task file. If not found, STOP: "Task {id} not found."
3. Append a timestamped entry to `## Notes`:
   - If the content is a single line, append:
     ```
     {YYYY-MM-DD}: {content}
     ```
   - If the content spans multiple lines, append:
     ```
     {YYYY-MM-DD}:
     {content block verbatim}
     ```
4. Update the `updated:` field in frontmatter.
5. Write the updated task file back to disk.
6. Run `bash .track/scripts/track-validate.sh`.
   - If validation fails, STOP and surface the validation error. Do not claim
     success.
7. Respond: "Added note to task {id}."

`context` is complete only after the task file is written and validation passes.

Never rewrite existing notes — append only. Do not open a PR or lock a mode.

## Definition of Done

- `pick` is done when a draft PR is opened and implementation is underway
- `resume` is done when the session's work is committed and pushed
- `empty` is done when the user is informed and given next steps

Do not report a task as "started" before a draft PR exists. Do not report
success before the mode reaches its definition of done.

## Glossary

- **Raw Status** — the `status:` field stored in a Track task file
- **Effective Status** — derived from raw status plus live open PR state; what the generated Track views show
- **Provisional PR** — an implementation PR opened as soon as work starts on a task; draft = active, ready-for-review = review
- **Project Brief** — a markdown scope contract in `.track/projects/{project_id}-{slug}.md`
- **Task** — a Track work item at `.track/tasks/{task_id}-{slug}.md` with YAML frontmatter and required body sections
- **View / Pointer** — a non-canonical navigation surface; `TODO.md`, `BOARD.md`, and `PROJECTS.md` are Track's generated views

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

`TODO.md`, `BOARD.md`, and `PROJECTS.md` are generated and gitignored. They are never canonical state.

The PR lifecycle runtime installed by `/track:init` comes from
`skills/work/scripts/track-pr-lint.sh` and
`skills/work/scripts/track-complete.sh`. Those sources install into the
adopting repo at `.track/scripts/track-pr-lint.sh` and
`.track/scripts/track-complete.sh`.

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
| `status` | `todo`, `active`, `review`, `blocked`, `done`, `cancelled` | Lifecycle position. |
| `mode` | `investigate`, `plan`, `implement` | What kind of work. |
| `priority` | `urgent`, `high`, `medium`, `low` | Relative importance. |
| `project_id` | Number string | Must match a brief in `projects/`. |
| `depends_on` | List of task IDs | Must be `done` before this task can start. |
| `files` | List of glob patterns | Files this task expects to touch. Used for overlap detection. |
| `pr` | URL string | Populated when completed via merged PR. |
| `cancelled_reason` | Free text | Required when `status: cancelled`. |
| `blocked_reason` | Free text | Required when `status: blocked`. |

## Raw vs Effective Status

1. If raw status is `done` or `cancelled` → effective status matches (terminal)
2. If raw status is `blocked` → effective = `blocked` (not terminal, but skips PR overlay)
3. If there's an open **draft** PR on `task/{id}-{slug}` → effective = `active`
4. If there's an open **ready-for-review** PR → effective = `review`
5. Otherwise → effective = `todo`

You must set `status: active` when opening a draft PR and `status: review` when marking it ready. CI enforces this. The post-merge workflow handles `status: done`.

## Before Starting Work

1. Read `TODO.md` and `BOARD.md`, or scan `.track/tasks/*.md`, for available work.
   If `.track/tasks/` does not exist or is empty, set mode to `empty` and skip to
   the closing message.
2. Check for plans — scan `.track/plans/*.md` (excluding README.md). If any plan
   files exist:
   - Read them for context
   - If a plan has a `task_id` in its frontmatter, suggest working that task
   - Tell the user: "Found plan: {title}. Linked to task {task_id}."
2.5. Check for Track hooks: if `.git/hooks/post-commit` (or `.husky/post-commit`)
     exists and contains `Deployed by track init` or `Track event emitter`,
     commit events are being emitted automatically.
     If hooks are not found, suggest: "Track hooks aren't installed — run
     `/track:init` to set them up."
3. Check `files:` globs against tasks already shown as `active` / `review` — avoid overlap
4. Pick work that has no unresolved `depends_on` blockers
5. Read the task's `## Context` and `## Notes` — previous sessions may have left important context
6. If the task's mode is `investigate`, focus on understanding and documenting findings rather than writing code
7. If the acceptance criteria seem incomplete or unclear, update them before starting implementation
8. Use a dedicated worktree or branch per task when possible. If continuing on an existing branch, the PR body handles linkage
9. If no open tasks exist (all tasks are `done` or `cancelled`), set mode to `empty`

## Working a Task (Provisional PR Lifecycle)

1. Create a branch from the default branch (or use the current branch)
2. First commit updates the task file only:
   - set raw `status: active`
   - update `updated:` to today
3. Push and open a **draft PR** immediately
   - Always include `Track-Task: {id}` on the first line of the PR body
   - Include the task ID in the title: `[{id}] Title` or `({id}) Title`
   - Optional label: `track:{id}`
   - CI resolves the task from PR body, labels, title, then branch name
   - If `gh pr create` fails (auth, network, permissions), STOP. Tell the user:
     "Could not open draft PR: {error}. Fix the issue and retry — Track requires
     a PR to track progress."
4. Do the implementation work with as many commits as needed
5. When ready for review:
   - Verify each acceptance criterion is met — cite the file and line that
     satisfies it, or flag as unverified. Do not claim "criteria met" without evidence.
   - set raw `status: review`
   - update `updated:`
   - mark the PR ready for review
6. When the PR merges, the post-merge workflow writes `status: done`, `pr:`, and `updated:` on the default branch

Example PR linkage:

```text
- Branch: any-branch-name
- Title: feat(skills): [7.2] refine refresh-track skill
- Body: Track-Task: 7.2
```

## Also-Completed (drive-by task completion)

When a PR's primary task is one thing but the work also fully resolves another small task, note it in the PR body. On merge, Track marks all listed tasks done.

Rules:
- One `Track-Task: {id}` for the primary task (required)
- One `Also-Completed: {id}` line per additional task (optional, max 2)
- The additional tasks must be genuinely completed, not partially addressed
- Same project preferred but not enforced

Example PR body:

```text
Track-Task: 7.1
Also-Completed: 7.2
```

Do NOT use Also-Completed for:
- Tasks that need their own review cycle
- Tasks in a different project with different reviewers
- Partially addressed work — open a separate PR instead

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

Calibration — this is the split threshold: a task that touches `src/api/auth.ts`
and `src/ui/dashboard.tsx` for the same feature is fine (cohesive). A task that
fixes a deploy bug AND refactors the test harness should split (independent changes).

To split: create new task(s) with proper `depends_on`, update the original task's acceptance criteria to reflect the reduced scope, and add a note explaining the split.

## Regenerating Track views

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

If `track-validate.sh` is not found, STOP: "Validation script missing. Run
`/track:init` to install it."
If it exits non-zero, fix every error before continuing. Do not commit invalid state.

## Persisting Plans

When any planning, investigation, or design work produces a plan during a task,
**automatically save it** to `.track/plans/` before the session ends. Do not wait
for the user to ask — persistence is the default.

1. Choose a filename: `{task_id}-{slug}.md` if working a task, or `{slug}.md` otherwise
2. Add YAML frontmatter with `title`, `created` (today's date), and `task_id`/`project_id`
   if applicable
3. Paste the plan content as the body — no reformatting needed
4. Commit the plan file alongside other work

Plans auto-expire after 7 days. If a plan should live longer, the user can update
its `created` date.

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

- Do not edit `BOARD.md`, `TODO.md`, or `PROJECTS.md` by hand — they are generated and will be overwritten
- Do not set `status: done` manually — the post-merge workflow handles this
- Do not create tasks without a matching project brief
- Do not use the same `files:` glob as an already-active task
- Do not skip reading `## Notes` and `## Context` before starting work
- Do not report a task as started without opening a draft PR
- Do not work a task whose `depends_on` has unresolved blockers
- Do not report success before the active mode reaches its definition of done
- Do not claim "acceptance criteria met" without citing the file and line for each criterion — verify or flag as unverified
- Do not silently switch modes — if `pick` discovers a `resume` situation, state the switch explicitly
- Do not emit a `track.link` event without validating the task ID exists
- Do not overwrite existing `## Notes` content — append only
