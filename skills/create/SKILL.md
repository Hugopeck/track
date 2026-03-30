---
name: create
description: |
  Create tasks and projects from natural language. Extract structure from loose
  descriptions — infer priority, mode, dependencies, and file scopes — then produce
  properly formatted Track files. Validate everything before reporting success.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

## Purpose

`/track:create` owns the full creation lifecycle for Track tasks and projects —
from parsing user input through file creation, validation, and reporting.

## What This Skill Owns

1. Parse user input to determine what to create
2. Lock the operating mode
3. Assign IDs and generate slugs
4. Write task and/or project files
5. Validate the result
6. Regenerate Track views
7. Report what was created

This skill does NOT own decomposition (that's `/track:decompose`) or working a
task (that's `/track:work`).

## Operating Modes

Lock one of these modes at the start and do not switch mid-run:

- `create-project` — user wants a new project brief only
- `create-task` — user wants one or more tasks under an existing project
- `create-both` — user describes a new project with tasks in a single request

## Definition of Done

- All files are written
- `bash .track/scripts/track-validate.sh` passes
- `bash .track/scripts/track-todo.sh --local --offline` regenerates `BOARD.md`, `TODO.md`, and `PROJECTS.md`
- The user sees what was created (IDs, titles, file paths)

Do not report success before validation passes.

## Creating a Project

When the user wants to create a new project:

1. Scan `.track/projects/` to find the next available project ID (highest number + 1)
2. Generate a slug from the project name (lowercase, hyphens, no special characters)
3. Check for collisions — if a file with the same slug already exists, pick the
   next available ID
4. Create `.track/projects/{id}-{slug}.md` with all required sections:

```markdown
# {Project Name}

## Goal
{Extracted from user description}

## Why Now
{Extracted or placeholder}

## In Scope
- {Items from description}

## Out Of Scope
- {Explicit exclusions if mentioned}

## Shared Context
{Background context if provided}

## Dependency Notes
{Cross-project dependencies if any}

## Success Definition
{Measurable outcomes}

## Candidate Task Seeds
- {Potential tasks identified from the description}
```

## Creating a Task

When the user wants to create a task:

1. Determine which project it belongs to (ask if ambiguous, or scan existing projects).
   If no projects exist in `.track/projects/`, STOP: "No projects found. Create a
   project first with `/track:create project: {name}` or use `/track:decompose`."
2. Scan `.track/tasks/` to find the next sequence number for that project:
   - List all files matching `{project_id}.*-*.md`
   - Take the highest sequence number and add 1
   - If no existing tasks, start at 1
3. Generate a slug from the task title (lowercase, hyphens, max 50 chars)
4. Check for collisions — if a file with the same ID or slug already exists,
   pick the next available sequence number
5. Before writing, show the extracted structure and confirm:
   ```
   Creating task {id}: {title}
     mode: {mode} | priority: {priority} | project: {project_id}
     depends_on: {deps} | files: {files}
   Correct? (y/n)
   ```
6. Create `.track/tasks/{project_id}.{sequence}-{slug}.md`:

```yaml
---
id: "{project_id}.{sequence}"
title: "{One-line objective}"
status: todo
mode: {investigate|plan|implement based on description}
priority: {urgent|high|medium|low based on description}
project_id: "{project_id}"
created: {today YYYY-MM-DD}
updated: {today YYYY-MM-DD}
depends_on: []
files: []
pr: ""
---

## Context
{Extracted from user description — what needs to happen and why}

## Acceptance Criteria
- [ ] {Primary outcome extracted from description}

## Notes
Created from: {brief summary of the user's request}
```

7. Infer `mode` from the description:
   - "investigate", "research", "explore", "decide" → `investigate`
   - "plan", "design", "architect" → `plan`
   - Everything else → `implement`
8. Infer `priority` from the description:
   - "urgent", "critical", "blocking" → `urgent`
   - "important", "high priority" → `high`
   - "nice to have", "low priority" → `low`
   - Default → `medium`
9. Infer `files` from the description if specific paths or patterns are mentioned
10. Infer `depends_on` if the user mentions tasks that must complete first

## After Creating

1. Run `bash .track/scripts/track-validate.sh` — fix any errors.
   If it exits non-zero, fix every error before continuing. Do not show the
   closing message until validation passes.
   If `track-validate.sh` is not found, STOP: "Validation script missing. Run
   `/track:init` to install it."
2. Run `bash .track/scripts/track-todo.sh --local --offline` — regenerate Track views
3. Show the closing message

## Closing Message Matrix

When creation completes, show exactly one closing message:

If mode is `create-project`:

```
Created project {id}: {name}
  → .track/projects/{id}-{slug}.md

Use /track:create to add tasks, or /track:decompose to break the goal into tasks.
```

If mode is `create-task` (single task):

```
Created task {id}: {title}
  → .track/tasks/{id}-{slug}.md
```

If mode is `create-task` (multiple tasks):

```
Created {N} tasks under project {project_id}:
  {id}: {title} → .track/tasks/{id}-{slug}.md
  {id}: {title} → .track/tasks/{id}-{slug}.md
```

If mode is `create-both`:

```
Created project {id}: {name}
  → .track/projects/{id}-{slug}.md

Created {N} tasks:
  {id}: {title} → .track/tasks/{id}-{slug}.md
  {id}: {title} → .track/tasks/{id}-{slug}.md
```

## Using $ARGUMENTS

`$ARGUMENTS` is the user's description of what they want to create. Parse it to
extract the task/project title, context, priority, and any other details.

Calibration — this is the vague/specific boundary:
- BAD: `/track:create fix stuff` — too vague, ask what specifically needs fixing
- BAD: `/track:create do the auth work` — what auth work? Ask.
- GOOD: `/track:create Add rate limiting to the API` — specific enough to infer
- GOOD: `/track:create project: Auth Rewrite — migrate from session tokens to JWTs`
- GOOD: `/track:create high priority: Fix the broken deploy script, depends on 1.2`

If the description is vague, ask a clarifying question rather than guessing. A
well-specified task saves more time than a fast-created one.

## Do Not

- Do not report success before `track-validate.sh` passes
- Do not guess when the description is vague — ask a clarifying question
- Do not overwrite existing task or project files without asking
- Do not create tasks without a matching project brief
- Do not skip collision checks on IDs and slugs
- Do not write files without confirming the extracted structure first
