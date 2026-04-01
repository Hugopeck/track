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
from parsing user input through discovery, plan confirmation, file creation,
validation, and reporting.

## Tone

Be maximally helpful. Infer everything you can from the user's description before
asking anything. When you do ask, use plain language and lead with a recommendation.

- Extract titles and priority from intent — never ask for them.
- When presenting options, recommend one: "This sounds like it belongs to project 2
  (API Hardening) — sound right?" not "Which of these 4 projects?"
- Batch related unknowns into a single question. Never fire off a list of 5 questions.
- Default to action. If you can infer it, infer it. Show your work in the plan so the
  user can correct you — that's faster than interrogating upfront.

## What This Skill Owns

1. Discover what the user wants to create (the discovery loop)
2. Confirm intent with a creation plan
3. Lock the operating mode
4. Assign IDs and generate slugs
5. Write task and/or project files
6. Validate the result
7. Regenerate Track views
8. Report what was created

This skill does NOT own decomposition (that's `/track:decompose`) or working a
task (that's `/track:work`).

## Operating Modes

Lock one of these modes after discovery completes. Do not switch mid-run:

- `create-project` — user wants a new project brief only
- `create-task` — user wants one or more tasks under an existing project
- `create-both` — user describes a new project with tasks in a single request

## Definition of Done

- Discovery is complete — all required fields resolved or defaulted
- The user confirmed the creation plan
- All files are written
- `bash .track/scripts/track-validate.sh` passes
- `bash .track/scripts/track-todo.sh --local --offline` regenerates `BOARD.md`, `TODO.md`, and `PROJECTS.md`
- The user sees what was created (IDs, titles, file paths)

Do not report success before validation passes.

---

## Phase 0 — Discovery

Before locking a mode or writing any files, run the discovery loop. The goal is to
extract a complete picture from the user's input — and only ask when you genuinely
cannot proceed.

### Step 1: Parse and infer

Read `$ARGUMENTS`. Extract every field you can:

| Field | Required for | How to resolve |
|-------|-------------|----------------|
| Intent (project / task / both) | Mode lock | Infer from keywords — "project:" means project; action verbs like "add", "fix", "implement" mean task; a project description with embedded tasks means both. Ask only if genuinely ambiguous. |
| Title / name | All modes | **Always extract — never ask.** The user's description *is* the title seed. Clean it up: capitalize, trim filler, keep it under one line. |
| Project assignment | `create-task` | Scan `.track/projects/`. One match → use it. Multiple matches → recommend the best fit and confirm. Zero matches → STOP (see "Creating a Task" below). |
| Goal / context | Projects | Extract from description. Only ask if the description is a bare phrase with no actionable detail (e.g., "project: Auth"). |
| Priority | All modes | **Always infer — never ask.** See priority inference rules below. |
| Mode | Tasks | Infer from verbs. Default `implement`. |
| Dependencies | Tasks | Infer from explicit mentions ("after 1.2", "depends on the auth task"). Default `[]`. |
| File scopes | Tasks | Infer from paths or patterns mentioned. Default `[]`. |

### Step 2: Check confidence

Compare what you extracted against the confidence checklist:

- **Intent** — resolved? If not, ask: "Are you describing a new project, a task, or both?"
- **Title** — always resolved (extracted from description).
- **Project assignment** (tasks only) — resolved? If ambiguous, recommend one.
- **Goal** (projects only) — enough substance to write a meaningful goal section? If not, ask one question: "What's the end goal here?"
- **Success Definition** (projects only) — if the user gave a goal but no success criteria, infer them from the goal (e.g., "migrate to JWTs" → "all endpoints use JWT auth, session tokens removed"). Only ask if you truly can't infer anything.
- **Priority** — always resolved (inferred or defaulted).

Fields with sensible defaults (mode, depends_on, files) never block. Proceed with
defaults and show them in the plan.

### Step 3: Ask (only if needed)

If gaps remain, ask **1–2 questions** maximum per round. Phrase them as
recommendations, not interrogations:

```
BAD:  "What is the project for this task? Please provide the project_id."
GOOD: "I see two projects that could fit — 1 (Track Improvements) and 2 (API Hardening).
       Based on your description, I'd go with 2. Sound right?"

BAD:  "What title would you like for this task?"
GOOD: (never ask — extract from the description)

BAD:  "What priority? What mode? What files? What dependencies?"
GOOD: (infer all of these — show them in the plan for correction)
```

Repeat steps 1–3 until confident, then proceed to plan confirmation.

### Priority inference rules

These apply to both projects and tasks:

- "urgent", "critical", "blocking", "broken", "down" → `urgent`
- "important", "high priority", "soon", "needs attention" → `high`
- "nice to have", "low priority", "when we get to it", "eventually" → `low`
- No signal → `medium`

### Mode inference rules (tasks only)

- "investigate", "research", "explore", "decide", "evaluate", "compare" → `investigate`
- "plan", "design", "architect", "spec out", "outline" → `plan`
- Everything else → `implement`

---

## Plan Confirmation

After discovery, generate a creation plan. Show the user exactly what will be
written before touching any files.

### For `create-task` (single):

```
## Creation Plan

Task {id}: {title}
  project: {project_id} — {project_name}
  mode: {mode} | priority: {priority}
  depends_on: {deps}
  files: {files}

Context:
  {2-3 sentence summary of what was extracted}

Acceptance Criteria:
  - [ ] {primary outcome}

Create this task? (y / edit / cancel)
```

### For `create-task` (multiple):

```
## Creation Plan

{N} tasks under project {project_id} — {project_name}:

| # | Title | Mode | Priority | Depends | Files |
|---|-------|------|----------|---------|-------|
| {id} | {title} | {mode} | {priority} | {deps} | {files} |

Create these tasks? (y / edit / cancel)
```

### For `create-project`:

```
## Creation Plan

Project {id}: {name}
  priority: {priority}

Goal: {extracted goal}
Success Definition: {extracted or "TBD"}
In Scope:
  - {items}

Create this project? (y / edit / cancel)
```

### For `create-both`:

```
## Creation Plan

Project {id}: {name}
  priority: {priority}
  Goal: {goal}

Tasks:
| # | Title | Mode | Priority | Depends | Files |
|---|-------|------|----------|---------|-------|
| {id} | {title} | {mode} | {priority} | {deps} | {files} |

Create project and {N} tasks? (y / edit / cancel)
```

### Handling `edit`

If the user replies with corrections ("change priority to high", "rename to X",
"add depends_on 1.2"), parse the correction, apply it, and regenerate the plan.
Do not restart discovery.

### Handling `cancel`

Stop. Do not write files. Respond: "Cancelled — nothing was created."

---

## Creating a Project

After the user confirms the plan:

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
- {verb phrase describing work unit} — {rough file scope or area}
- {verb phrase describing work unit} — {rough file scope or area}
```

Each seed should be a concrete work unit with a rough file scope hint, not a vague
category. Extract these from the user's description. Example: if the user says
"add auth with JWT and rate limiting", the seeds become:
- Add JWT authentication — src/auth/**
- Add rate limiting middleware — src/middleware/**

These seeds are what `/track:decompose` reads to produce tasks automatically —
the more specific they are, the better the decomposition.

---

## Creating a Task

After the user confirms the plan:

1. Verify a matching project exists. If no projects exist in `.track/projects/`,
   STOP: "No projects found. Create a project first with `/track:create project:
   {name}` or use `/track:decompose`."
2. Scan `.track/tasks/` to find the next sequence number for that project:
   - List all files matching `{project_id}.*-*.md`
   - Take the highest sequence number and add 1
   - If no existing tasks, start at 1
3. Generate a slug from the task title (lowercase, hyphens, max 50 chars)
4. Check for collisions — if a file with the same ID or slug already exists,
   pick the next available sequence number
5. Create `.track/tasks/{project_id}.{sequence}-{slug}.md`:

```yaml
---
id: "{project_id}.{sequence}"
title: "{One-line objective}"
status: todo
mode: {investigate|plan|implement}
priority: {urgent|high|medium|low}
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

---

## After Creating

1. Run `bash .track/scripts/track-validate.sh` — fix any errors.
   If it exits non-zero, fix every error before continuing. Do not show the
   closing message until validation passes.
   If `track-validate.sh` is not found, STOP: "Validation script missing. Run
   `/track:setup-track` to install it."
2. Run `bash .track/scripts/track-todo.sh --local --offline` — regenerate Track views
3. Show the closing message

---

## Closing Message Matrix

When creation completes, show exactly one closing message:

If mode is `create-project`:

```
Created project {id}: {name}
  → .track/projects/{id}-{slug}.md

Next step: run /track:decompose to break this project into tasks.
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

Next step: run /track:decompose if you want to break the project down further.
```

---

## Using $ARGUMENTS

`$ARGUMENTS` is the user's description of what they want to create. Feed it into
the discovery loop — extract title, context, priority, and any other details.

Calibration — this is the vague/specific boundary:

- BAD: `/track:create fix stuff` — too vague. Ask what specifically needs fixing.
- BAD: `/track:create do the auth work` — what auth work? Ask.
- GOOD: `/track:create Add rate limiting to the API` — specific enough. Title:
  "Add rate limiting to the API", mode: implement, priority: medium.
- GOOD: `/track:create project: Auth Rewrite — migrate from session tokens to JWTs`
  — clear project. Title: "Auth Rewrite", goal: migrate from session tokens to JWTs.
- GOOD: `/track:create high priority: Fix the broken deploy script, depends on 1.2`
  — title: "Fix the broken deploy script", priority: high, depends_on: [1.2].

If the description is too vague to extract a meaningful title, ask one clarifying
question. A well-specified task saves more time than a fast-created one.

---

## Do Not

- Do not report success before `track-validate.sh` passes
- Do not ask for the title — always extract it from the description
- Do not ask for priority — always infer it
- Do not fire off a list of questions — ask 1–2 at a time, max
- Do not guess when the description is genuinely vague — ask a clarifying question
- Do not overwrite existing task or project files without asking
- Do not create tasks without a matching project brief
- Do not skip collision checks on IDs and slugs
- Do not write files before the user confirms the creation plan
- Do not switch operating modes mid-run
