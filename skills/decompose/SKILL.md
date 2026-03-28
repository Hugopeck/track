---
name: decompose
description: |
  Break an ambiguous goal into concrete, parallelizable tasks. Explore the codebase
  to find natural seams, propose a breakdown with non-overlapping file scopes, and
  only create files after the user confirms. Prefer fewer, focused tasks over
  comprehensive coverage.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

## Purpose

`/track:decompose` owns the full decomposition lifecycle — from understanding a
goal through codebase exploration, proposing a task breakdown, and creating files
after user confirmation.

## What This Skill Owns

1. Parse the goal from user input
2. Determine the operating mode
3. Explore the codebase for natural seams
4. Propose a task breakdown with non-overlapping file scopes
5. Wait for user confirmation
6. Create task (and optionally project) files
7. Validate and regenerate Track views
8. Report what was created

This skill does NOT own creating individual tasks outside a decomposition
(that's `/track:create`).

## Operating Modes

Lock one of these modes at the start and do not switch mid-run:

- `new-project` — the goal implies a new project; create a project brief and
  tasks together
- `extend-project` — the goal extends an existing project; add tasks only

## Definition of Done

- User confirmed the breakdown
- All files are written
- `bash .track/scripts/track-validate.sh` passes
- `bash .track/scripts/track-todo.sh --local --offline` regenerates `BOARD.md`, `TODO.md`, and `PROJECTS.md`
- The user sees what was created

Do not report success before validation passes.

## Steps

### Phase 1: Understand the goal

1. Parse `$ARGUMENTS` to understand what the user wants to accomplish
2. Determine the operating mode:
   - If the goal maps to an existing project in `.track/projects/`, set mode to
     `extend-project`
   - If the goal requires a new project, set mode to `new-project`
   - If ambiguous, ask the user

### Phase 2: Explore the codebase

1. Use Glob and Grep to understand module boundaries relevant to the goal
2. Identify which files and directories will need to change
3. Look for natural seams where work can be split

Do not skip this phase. Decomposition without codebase exploration produces
tasks with wrong file scopes and missed dependencies.

If exploration reveals the goal is too vague to decompose (no clear module
boundaries, no obvious seams), STOP and ask the user to narrow the goal.
If the goal maps to a single file or function, suggest `/track:create` instead —
decomposition is for multi-task work.

### Phase 3: Propose task breakdown

#### Collision avoidance

Before proposing tasks:

1. Scan `.track/tasks/` for existing task IDs under the target project
2. Check `files:` globs of existing `active` or `review` tasks — proposed globs
   must not overlap with them
3. Use the next available sequence numbers for proposed task IDs

#### Proposal format

Present a table to the user:

```
| # | Title | Mode | Priority | Depends | Files |
|---|-------|------|----------|---------|-------|
| {project}.1 | Foundation: ... | implement | high | — | src/core/** |
| {project}.2 | Feature: ... | implement | high | {project}.1 | src/api/** |
| {project}.3 | Tests: ... | implement | medium | {project}.2 | tests/** |
```

#### Guidelines

- One task per independent unit of work
- Non-overlapping `files:` scopes between tasks that could run in parallel
- Use `depends_on` to sequence foundation work before integration work
- Prefer small, reviewable PRs — each task should be mergeable on its own
- `investigate` or `plan` tasks before `implement` tasks when the path is uncertain
- When uncertain about scope, prefer creating an `investigate` task first rather than guessing at implementation tasks
- Default to `medium` priority unless the user indicates otherwise
- Ask clarifying questions if the goal is ambiguous enough that two reasonable engineers would decompose it differently

#### Calibration — good vs. bad decomposition

GOOD decomposition of "add user authentication":
```
| 1.1 | Add user model and migration     | implement | high | —   | src/models/** db/migrate/** |
| 1.2 | Add login/signup API endpoints    | implement | high | 1.1 | src/api/auth/**             |
| 1.3 | Add session middleware            | implement | high | 1.1 | src/middleware/**            |
```
Each task is independently mergeable, files don't overlap, dependencies are minimal.

BAD decomposition of the same goal:
```
| 1.1 | Set up auth backend  | implement | high | — | src/** |
| 1.2 | Set up auth frontend | implement | high | — | src/** |
| 1.3 | Test auth            | implement | low  | 1.1, 1.2 | tests/** |
```
Overlapping `files:` scopes, vague titles, tests deferred to a separate task
instead of shipped with each feature.

#### Verification before presenting

Before presenting the proposal, verify: every file in the codebase relevant to
the goal maps to exactly one task's `files:` scope. If a file is orphaned (relevant
but not covered), either add it to a task or explain why it's excluded.

### Phase 4: Confirm and create

1. Wait for the user to confirm, modify, or reject the proposal.
   If the user rejects entirely, ask what they'd change. Do not silently
   create files. If they want a fundamentally different approach, return to
   Phase 2 with the new direction.
2. Once confirmed, create all files:
   - If mode is `new-project`, create the project brief first
   - Create all task files using `/track:create` conventions:
     - Correct dotted IDs with next available sequence numbers
     - Proper frontmatter with all required fields
     - `## Context`, `## Acceptance Criteria`, `## Notes` sections
3. Save the decomposition as a plan to `.track/plans/{project_id}-decomposition.md`
   with frontmatter (`title`, `created`, `project_id`) and the breakdown as the body
4. Run `bash .track/scripts/track-validate.sh` — fix any errors.
   If it exits non-zero, fix every error before continuing.
   If `track-validate.sh` is not found, STOP: "Validation script missing. Run
   `/track:init` to install it."
5. Run `bash .track/scripts/track-todo.sh --local --offline`
6. Show the closing message

## Closing Message Matrix

When decomposition completes, show exactly one closing message:

If mode is `new-project`:

```
Created project {id}: {name}
  → .track/projects/{id}-{slug}.md

Created {N} tasks:
| ID | Title | File |
|----|-------|------|
| {id} | {title} | .track/tasks/{id}-{slug}.md |
```

If mode is `extend-project`:

```
Added {N} tasks to project {id}: {name}
| ID | Title | File |
|----|-------|------|
| {id} | {title} | .track/tasks/{id}-{slug}.md |
```

## Do Not

- Do not create files before the user confirms the breakdown
- Do not skip codebase exploration (Phase 2)
- Do not report success before `track-validate.sh` passes
- Do not propose `files:` globs that overlap with existing active or review tasks
- Do not propose more than 10 tasks without asking — prefer fewer, focused tasks
- Every task must have at least one acceptance criterion
- Total task count should be 2–10 for most goals; ask if it seems like more are needed
