---
name: decompose
description: |
  Break an existing project into concrete, parallelizable agent work units.
  Reads the project brief as the sole specification — no user input needed.
  Explores the codebase to find natural seams, determines file scopes, and
  creates task files automatically. Re-run it after updating a project brief
  to re-decompose with fresh tasks.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

## Purpose

`/track:decompose` turns a project brief into ready-to-work task files. It reads
the project, explores the codebase, and creates tasks — fully automatic, no
questions asked. The project brief (written by `/track:create`) is the spec.

If the project was already decomposed and the brief has changed, decompose
cancels stale tasks and creates new ones for the remaining scope.

## Tone

Operational and brief. Narrate progress so the user knows what's happening, but
don't ask questions — the project brief is the spec.

- "Reading project 3: API Hardening..."
- "Found 2 existing tasks (1 active, 1 done) — preserving those."
- "Cancelling 3 stale todo tasks from previous decomposition."
- "Exploring codebase for parallelism boundaries..."

## What This Skill Owns

1. Load an existing project brief
2. Determine the operating mode (fresh vs re-decompose)
3. Handle existing tasks (preserve committed work, cancel stale plans)
4. Explore the codebase for module boundaries and parallelism opportunities
5. Generate the task breakdown optimized for parallel agent execution
6. Create task files
7. Save the decomposition plan
8. Validate and regenerate Track views
9. Report what was created

This skill does NOT own creating projects (that's `/track:create`) or creating
individual tasks outside a decomposition (also `/track:create`).

## Operating Modes

Determined automatically — do not switch mid-run:

- `fresh` — no existing tasks under this project. Decompose from scratch.
- `re-decompose` — tasks already exist. Preserve committed work, cancel stale
  `todo` tasks, create new tasks for remaining scope.

Detection: scan `.track/tasks/` for files matching `{project_id}.*-*.md`.
None found → `fresh`. Some found → `re-decompose`.

## Definition of Done

- All task files are written
- Stale tasks cancelled (if re-decompose)
- Decomposition plan saved to `.track/plans/`
- `bash .track/scripts/track-validate.sh` passes
- `bash .track/scripts/track-todo.sh --local --offline` regenerates views
- The user sees what was created

Do not report success before validation passes.

---

## Core Idea: Maximize Parallel Agentic Throughput

Decompose doesn't think in human-sized atomic tasks. It thinks in **agent work
units** — chunks optimized for parallel execution by multiple coding agents.

The optimization target is **wall-clock time to project completion**, not task
count. Four principles drive every split/merge decision:

**1. Merge sequential work into one task.** If step B can't start until step A
finishes, and both touch the same files — they're one task. Making an agent wait
for another agent's output is wasted parallelism.

**2. Split at parallelism boundaries.** When two pieces of work touch
non-overlapping files and have no data dependency — they're separate tasks. Two
agents work them simultaneously.

**3. Batch by shared context.** If 2–3 small changes need deep understanding of
the same module, bundle them. One agent loads that context once and does all
three. Splitting them means three agents each rebuilding the same mental model.

**4. Split when speed wins.** If a large module has two independent subsystems,
split even if they share a parent directory — two agents finishing in 30 minutes
beats one agent taking 50 minutes.

The balancing act: fewer tasks = less coordination overhead but less parallelism.
More tasks = more parallelism but more merge conflicts and dependency chains.
Decompose finds the sweet spot by reading the codebase structure and identifying
natural parallelism boundaries.

### Calibration

"Add user authentication" with model + migration + middleware + API endpoints:

GOOD — **2 tasks**:
```
| 1.1 | Auth foundation (model, migration, middleware) | implement | high | —   | src/models/** db/migrate/** src/middleware/** |
| 1.2 | Auth API endpoints                             | implement | high | 1.1 | src/api/auth/**                               |
```
The model/migration/middleware chain is sequential and shares context — splitting
it wastes time. The API endpoints are a separate module that can start once the
foundation lands.

BAD — **4 tasks** (one per step): the migration can't run without the model, the
middleware can't test without the migration. Three agents sitting idle waiting
on each other.

BAD — **1 task** (everything): no parallelism at all. The API endpoints could
have been worked simultaneously.

---

"Refactor logging across 4 independent services":

GOOD — **4 tasks** (one per service): each is independent, same pattern applied
in parallel.

BAD — **1 task**: an agent touching all 4 services creates a massive PR and
can't parallelize.

---

## Phase 1: Load the Project

1. Parse `$ARGUMENTS` to identify the target project.
   - If the user passed a project ID or name, find it in `.track/projects/`.
   - If only one project exists, use it.
   - If ambiguous, STOP: "Multiple projects found. Specify which one:
     `/track:decompose {project_id}`"
   - If no projects exist, STOP: "No projects found. Create one first with
     `/track:create`."

2. Read the project brief. Extract:
   - `## Goal` — what to accomplish
   - `## In Scope` / `## Out Of Scope` — boundaries
   - `## Candidate Task Seeds` — rough work units with file scope hints
   - `## Success Definition` — done criteria

   If the project brief lacks a Goal or has no actionable detail, STOP:
   "Project {id} doesn't have enough detail to decompose. Update the project
   brief and try again."

---

## Phase 2: Handle Existing Tasks

1. Scan `.track/tasks/` for files matching `{project_id}.*-*.md`
2. If none found → mode is `fresh`. Skip to Phase 3.
3. If tasks exist → mode is `re-decompose`. Categorize each:

   - **Preserve** (`active`, `review`, `done`): committed or completed work.
     Do not touch these files. Record their `files:` scopes as occupied.
   - **Cancel** (`todo`): stale planning artifacts from the previous
     decomposition. Set `status: cancelled`, add
     `cancelled_reason: "re-decomposed"`, update `updated:` to today.
   - **Blocked**: check if the blocking reason references a now-done or
     cancelled task. If so, cancel it (stale). If still relevant, preserve it.

4. Narrate: "Found {N} existing tasks — preserving {X} (active/done),
   cancelling {Y} stale todo tasks."

---

## Phase 3: Explore the Codebase

Use Glob and Grep to understand module boundaries relevant to the project goal.

Look specifically for:
- **Module boundaries** — separate directories, packages, or services that can
  be worked independently
- **Data flow dependencies** — which changes must land before others can start
- **Shared context clusters** — files that an agent would need to understand
  together to do meaningful work
- **Test co-location** — whether tests can run independently per task

Map each candidate task seed from the project brief to actual files in the
codebase. If a seed doesn't map to real files, drop it or flag it.

Exclude file scopes already owned by preserved tasks (from Phase 2).

Do not skip this phase. Decomposition without codebase exploration produces
tasks with wrong file scopes and missed dependencies.

If exploration reveals the project scope maps to a single file or function,
STOP: "This project maps to a single change — use `/track:create` instead."

---

## Phase 4: Generate Breakdown and Create Files

### Collision avoidance

1. Scan `.track/tasks/` for existing task IDs under this project
2. Check `files:` globs of preserved tasks — new globs must not overlap
3. Use the next available sequence numbers for new task IDs

### Split/merge decisions

For each candidate task seed, decide whether to merge it with adjacent seeds or
keep it separate. Apply the four principles from "Core Idea":

- Seeds that form a sequential chain touching the same files → merge
- Seeds with non-overlapping file scopes and no data dependency → separate tasks
- Seeds requiring the same deep module context → merge
- Seeds in independent subsystems → separate tasks even if in the same directory

### Task creation

Create each task file with:
- Correct dotted IDs with next available sequence numbers
- Proper frontmatter: `id`, `title`, `status: todo`, `mode`, `priority`,
  `project_id`, `created`, `updated`, `depends_on`, `files`, `pr: ""`
- `## Context` section explaining what needs to happen and why
- `## Acceptance Criteria` with at least one criterion
- `## Notes` section: "Created by decompose from project {project_id}"

### Priority inference

- Infer from the project brief's priority and the task's position in the
  dependency chain. Foundation tasks that block others → `high`.
  Independent tasks → match project priority or `medium`.

### Save the decomposition plan

Save to `.track/plans/{project_id}-decomposition.md` with frontmatter
(`title`, `created`, `project_id`) and the breakdown table as the body.

### Validate and regenerate

1. Run `bash .track/scripts/track-validate.sh` — fix any errors.
   If it exits non-zero, fix every error before continuing.
   If `track-validate.sh` is not found, STOP: "Validation script missing. Run
   `/track:setup-track` to install it."
2. Run `bash .track/scripts/track-todo.sh --local --offline`

---

## Closing Message Matrix

When decomposition completes, show exactly one closing message.

If mode is `fresh`:

```
Decomposed project {id}: {name} into {N} tasks:

| ID | Title | Mode | Priority | Depends | Files |
|----|-------|------|----------|---------|-------|
| {id} | {title} | {mode} | {priority} | {deps} | {files} |

Plan saved → .track/plans/{project_id}-decomposition.md
```

If mode is `re-decompose`:

```
Re-decomposed project {id}: {name}

Preserved {X} tasks (active/done):
  {id}: {title}

Cancelled {Y} stale tasks:
  {id}: {title}

Created {Z} new tasks:
| ID | Title | Mode | Priority | Depends | Files |
|----|-------|------|----------|---------|-------|
| {id} | {title} | {mode} | {priority} | {deps} | {files} |

Plan saved → .track/plans/{project_id}-decomposition.md
```

---

## Do Not

- Do not ask the user any questions — the project brief is the spec
- Do not create a new project (that's `/track:create`)
- Do not modify preserved tasks (active/review/done)
- Do not propose `files:` globs that overlap with preserved tasks
- Do not skip codebase exploration (Phase 3)
- Do not report success before `track-validate.sh` passes
- Do not create more than 10 tasks without strong justification — prefer fewer,
  well-scoped agent work units over many tiny tasks
- Do not split sequential work that shares context into separate tasks — merge it
- Do not create tasks with overlapping `files:` scopes that could run in parallel
