---
name: decompose
description: |
  Break a goal into Track tasks with correct dependencies and non-overlapping file
  scopes. Explores the repo to understand module boundaries, proposes a task
  breakdown, and creates task files after user confirmation.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

## Purpose

Take a high-level goal and produce a set of Track tasks that can be worked in
parallel where possible, with explicit dependencies where not.

## Steps

### Phase 1: Understand the goal

1. Parse `$ARGUMENTS` to understand what the user wants to accomplish
2. Identify which project this belongs to (scan `.track/projects/`, ask if ambiguous)

### Phase 2: Explore the codebase

1. Use Glob and Grep to understand module boundaries relevant to the goal
2. Identify which files and directories will need to change
3. Look for natural seams where work can be split

### Phase 3: Propose task breakdown

Present a table to the user:

```
| # | Title | Mode | Priority | Depends | Files |
|---|-------|------|----------|---------|-------|
| {project}.1 | Foundation: ... | implement | high | — | src/core/** |
| {project}.2 | Feature: ... | implement | high | {project}.1 | src/api/** |
| {project}.3 | Tests: ... | implement | medium | {project}.2 | tests/** |
```

Guidelines:
- One task per independent unit of work
- Non-overlapping `files:` scopes between tasks that could run in parallel
- Use `depends_on` to sequence foundation work before integration work
- Prefer small, reviewable PRs — each task should be mergeable on its own
- `investigate` or `plan` tasks before `implement` tasks when the path is uncertain
- Default to `medium` priority unless the user indicates otherwise

### Phase 4: Confirm and create

1. Ask the user to confirm, modify, or reject the proposal
2. Once confirmed, create all task files using the `/track:create` conventions:
   - Correct dotted IDs with next available sequence numbers
   - Proper frontmatter with all required fields
   - `## Context`, `## Acceptance Criteria`, `## Notes` sections
3. Run `bash scripts/track-validate.sh`
4. Run `bash scripts/track-todo.sh --local --offline`
5. Show the updated TODO.md summary

## Rules

- Never create tasks without user confirmation of the breakdown
- Every task must have at least one acceptance criterion
- `files:` globs must not overlap between tasks that don't have a dependency chain
- Total task count should be 2-10 for most goals; ask if it seems like more are needed
