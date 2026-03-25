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
7. Validate and regenerate TODO.md
8. Report what was created

This skill does NOT own creating individual tasks outside a decomposition
(that's `/track:create`).

## Operating Modes

Track one of these modes for the entire run:

- `new-project` — the goal implies a new project; create a project brief and
  tasks together
- `extend-project` — the goal extends an existing project; add tasks only

## Definition of Done

- User confirmed the breakdown
- All files are written
- `bash scripts/track-validate.sh` passes
- `bash scripts/track-todo.sh --local --offline` regenerates TODO.md
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

### Phase 4: Confirm and create

1. Wait for the user to confirm, modify, or reject the proposal
2. Once confirmed, create all files:
   - If mode is `new-project`, create the project brief first
   - Create all task files using `/track:create` conventions:
     - Correct dotted IDs with next available sequence numbers
     - Proper frontmatter with all required fields
     - `## Context`, `## Acceptance Criteria`, `## Notes` sections
3. Run `bash scripts/track-validate.sh` — fix any errors
4. Run `bash scripts/track-todo.sh --local --offline`
5. Show the closing message

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
