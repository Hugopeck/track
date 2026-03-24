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

Create new Track tasks or projects from a description. Handles ID assignment,
frontmatter generation, and validation automatically.

## Creating a Project

When the user wants to create a new project:

1. Scan `.track/projects/` to find the next available project ID (highest number + 1)
2. Generate a slug from the project name (lowercase, hyphens, no special characters)
3. Create `.track/projects/{id}-{slug}.md` with all required sections:

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

1. Determine which project it belongs to (ask if ambiguous, or scan existing projects)
2. Scan `.track/tasks/` to find the next sequence number for that project:
   - List all files matching `{project_id}.*-*.md`
   - Take the highest sequence number and add 1
   - If no existing tasks, start at 1
3. Generate a slug from the task title (lowercase, hyphens, max 50 chars)
4. Create `.track/tasks/{project_id}.{sequence}-{slug}.md`:

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

5. Infer `mode` from the description:
   - "investigate", "research", "explore", "decide" → `investigate`
   - "plan", "design", "architect" → `plan`
   - Everything else → `implement`
6. Infer `priority` from the description:
   - "urgent", "critical", "blocking" → `urgent`
   - "important", "high priority" → `high`
   - "nice to have", "low priority" → `low`
   - Default → `medium`
7. Infer `files` from the description if specific paths or patterns are mentioned
8. Infer `depends_on` if the user mentions tasks that must complete first

## After Creating

1. Run `bash scripts/track-validate.sh` — fix any errors
2. Run `bash scripts/track-todo.sh --local --offline` — regenerate TODO.md
3. Show the user what was created

## Using $ARGUMENTS

`$ARGUMENTS` is the user's description of what they want to create. Parse it to
extract the task/project title, context, priority, and any other details.

If the description is vague (e.g., "fix the thing"), ask a clarifying question rather than guessing. A well-specified task saves more time than a fast-created one.

Examples:
- `/track:create Add rate limiting to the API` → creates a task
- `/track:create project: Auth Rewrite — migrate from session tokens to JWTs` → creates a project
- `/track:create high priority: Fix the broken deploy script, depends on 1.2` → creates a high-priority task with dependency
