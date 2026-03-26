---
name: init
description: |
  Set up Track from scratch or re-run it on an existing Track repo. Scaffold
  everything an adopting repo needs — directories, scripts, CI workflows, and
  the CLAUDE.md protocol section — then scan existing markdown for importable
  tasks and projects. If nothing is found, create an onboarding project that
  teaches the user Track's workflow by having them execute their first task.
  Upgrades must continue through the full init tail unless the user aborts.
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

## Purpose

`/track:init` owns the full Track initialization lifecycle for the current
repository. That includes first-time setup, safe re-runs on existing Track
repos, importing existing markdown work, onboarding fallback, final validation,
and the closing handoff.

## What This Skill Owns

This skill does not stop at copying files. It owns the entire init flow:

1. Detect the current repo state
2. Install or refresh Track's files
3. Scan for importable markdown tasks and projects
4. Fall back to onboarding if nothing is imported
5. Verify the final state and hand the user off cleanly

If the user invoked `/track:init`, your job is to complete that lifecycle unless
they explicitly abort.

## Scaffold Location

All scaffold files live in `${CLAUDE_SKILL_DIR}/scaffold/`. This directory contains
the canonical copies of everything that gets installed into the adopting repo.
Always read scaffold files from there. Do not hardcode scaffold contents.

## Operating Modes

Track one of these modes for the entire run:

- `fresh-init` — `.track/` did not exist when the command started
- `upgrade-continue` — `.track/` already existed, the user chose to continue,
  and you must refresh installed assets before continuing through import,
  onboarding fallback, verify, and handoff

There is no "upgrade-only" mode in this skill. If `.track/` already exists, the
only valid choices are:

- continue the full init flow
- abort

## Definition of Done

`/track:init` is done only when the active mode reaches the end of the full flow:

- `fresh-init` is done only after Phases 2–10 complete
- `upgrade-continue` is done only after the upgrade work completes and then
  Phases 8–10 complete

Do not report success before the active mode reaches Phase 10.

## Initialization Steps

### Phase 1: Check existing state and lock the mode

1. Check whether `.track/` already exists.
2. If `.track/` does not exist:
   - Set mode to `fresh-init`
   - Continue immediately to Phase 2
3. If `.track/` already exists:
   - Ask the user: "Track is already set up. Refresh the installed Track files
     and continue the full init flow?"
   - Present only these choices:
     - **Continue upgrade**
     - **Abort**
   - If the user chooses **Continue upgrade**:
     - Set mode to `upgrade-continue`
     - Continue immediately to Phase 3, then automatically continue through the
       rest of the flow
   - If the user chooses **Abort**, stop
4. Check if `.track/scripts/track-common.sh` exists — warn if other Track scripts exist
   without `.track/`

### Phase 2: Create or repair `.track/` directory structure

This phase always ensures the required directory structure exists. The difference
is whether you are creating it for the first time or repairing missing pieces.

- In `fresh-init`, create the full structure
- In `upgrade-continue`, only create missing pieces; do not duplicate or replace
  existing user content unless the rules below require it

Steps:

1. Ensure `.track/` exists
2. If `.track/README.md` does not exist, read `${CLAUDE_SKILL_DIR}/scaffold/track/README.md`
   and write it to `.track/README.md`
3. Ensure `.track/projects/` exists
4. If `.track/projects/README.md` does not exist, read
   `${CLAUDE_SKILL_DIR}/scaffold/track/projects/README.md` and write it to
   `.track/projects/README.md`
5. Ensure `.track/tasks/` exists
6. If `.track/tasks/` is empty, create `.track/tasks/.gitkeep`
7. Ensure `.track/plans/` exists
8. If `.track/plans/README.md` does not exist, read
   `${CLAUDE_SKILL_DIR}/scaffold/track/plans/README.md` and write it to
   `.track/plans/README.md`

### Phase 3: Install scripts

1. Ensure `.track/scripts/` exists
2. For each script in `${CLAUDE_SKILL_DIR}/scaffold/track/scripts/`:
   - Read the scaffold version
   - Write to `.track/scripts/{filename}`
   - Make executable with `chmod +x`
3. Scripts to install:
   - `track-common.sh`
   - `track-validate.sh`
   - `track-todo.sh`
   - `track-pr-lint.sh`
   - `track-complete.sh`

### Phase 4: Install GitHub workflows

1. Ensure `.github/workflows/` exists
2. For each workflow in `${CLAUDE_SKILL_DIR}/scaffold/github-workflows/`:
   - Read the scaffold version
   - Write to `.github/workflows/{filename}`
3. Workflows to install:
   - `track-validate.yml`
   - `track-pr-lint.yml`
   - `track-complete.yml`

### Phase 5: Install Conductor config

1. Read `${CLAUDE_SKILL_DIR}/scaffold/conductor.json`
2. If `conductor.json` does not already exist at the repo root, write it there
3. If it already exists, ask the user whether to replace it

### Phase 6: Update `.gitignore`

1. Read `.gitignore` (or create it if absent)
2. If `TODO.md` is not already listed, append it

### Phase 7: Update `CLAUDE.md`

1. Read `CLAUDE.md` (or create it if absent)
2. Check if it already contains a `## Track` section
3. If not, read `${CLAUDE_SKILL_DIR}/scaffold/CLAUDE_TRACK_SECTION.md` and append
   it to `CLAUDE.md`
4. If yes, ask the user whether to replace the existing Track section

### Transition after Phase 7

- If mode is `fresh-init`, continue to Phase 8
- If mode is `upgrade-continue`, continue to Phase 8
- Never conclude the skill after Phase 3, 4, 5, 6, or 7
- Upgrading installed files is not completion; it is only the setup for the
  import/onboarding tail

### Phase 8: Import from existing markdown

Phase 8 applies to both fresh installs and upgraded repos. Use it for:

- new repos that already have markdown planning artifacts
- existing Track repos that adopted Track before import/onboarding existed
- existing Track repos where import was missed previously

Scan the repo for markdown files that contain tasks, TODOs, roadmaps, or project
notes. If anything is found, let the user pick which items to import into Track.

#### Phase 8a: Scan

1. Use `Glob` to find `**/*.md`, then filter out files under `.track/`,
   `node_modules/`, `.git/`, and `vendor/`, and skip `CHANGELOG.md`
2. **Size guard**: if more than 200 markdown files are found, limit scanning to
   known high-signal filenames (`TODO.md`, `ROADMAP.md`, `BACKLOG.md`,
   `TASKS.md`, `PLAN.md`) plus files in the repo root and `docs/` directory.
   Tell the user: "Found N markdown files; scanning high-signal files only."
3. Use `Grep` across matched files to find task-like content:
   - Checkbox patterns: `- [ ]`, `- [x]`
   - Headings (case-insensitive) matching: TODO, Tasks, Action Items, Backlog,
     Roadmap, Milestones, Goals, Next Steps, Planned, Upcoming
4. `Read` files that matched (max 500 lines per file; note if truncated)
5. If no markdown files are found, or none contain task-like content, print:
   "No importable tasks or projects found in existing markdown. Skipping import."
   Then continue to Phase 9

#### Phase 8b: Extract candidates

Read the matched content and extract discrete work items:

- **Projects**: a heading or file section that represents a broad initiative
  with multiple sub-items (for example, a `## Auth Rewrite` heading with several
  bullets underneath)
- **Tasks**: individual checkbox items (`- [ ] ...`), individual bullets under a
  planning heading, or standalone items from TODO/BACKLOG files
- **Orphan grouping**: tasks that don't belong to a clear project go under an
  auto-generated project called "Imported Backlog"
- **Deduplication**: if the same item text appears in multiple files (after
  stripping markdown formatting, leading dashes, and checkboxes), keep only the
  first occurrence
- **Cap at 30 items**: if more than 30 candidates are found, keep the top 30
  (prioritizing known-filename sources like `TODO.md`, `ROADMAP.md`) and note:
  "Found N total items; showing top 30. Use `/track:create` to add more later."

Infer fields for each candidate (mirrors `/track:create` conventions):

| Field | Inference rule |
|-------|---------------|
| `mode` | "investigate", "research", "explore", "decide" → `investigate`; "plan", "design", "architect" → `plan`; default → `implement` |
| `priority` | "urgent", "critical", "blocking" → `urgent`; "important", "high priority" → `high`; "nice to have", "low priority" → `low`; default → `medium` |
| `status` | `- [x]` checked items → `done`; everything else → `todo` |
| `depends_on` | `[]` (cannot infer from raw markdown) |
| `files` | `[]` (cannot infer reliably) |

#### Phase 8c: Write candidate files

Before writing anything, inspect existing `.track/projects/` and `.track/tasks/`
content so you can avoid collisions.

1. Never overwrite existing task or project files without asking
2. If a candidate project or task ID would collide with an existing file, choose
   the next available project ID or task sequence number
3. If a slug would collide, keep the existing file untouched and choose the next
   available ID for the imported item
4. For each candidate project, write a project brief to
   `.track/projects/{id}-{slug}.md` with all required sections. Fill `## Goal`
   from extracted content; use placeholder text for other sections.
5. For each candidate task, write a task file to
   `.track/tasks/{project_id}.{seq}-{slug}.md` with full YAML frontmatter and
   required body sections (`## Context`, `## Acceptance Criteria`, `## Notes`).
6. In `## Context`, reference the source: "Imported from `{source_file}`, line
   {N}."
7. In `## Notes`, write: "Auto-imported during `/track:init`."
8. Preserve all existing user-authored Track content

#### Phase 8d: Generate preview and present selection

1. Run `bash .track/scripts/track-todo.sh --local --offline`
2. Read the generated `TODO.md` and display it to the user
3. Below the TODO.md preview, present a numbered selection list. Number each
   discovered item sequentially (projects first, then tasks grouped under their
   project):

```
Found 8 items from 3 files:

  1. [Project] Auth Rewrite (from ROADMAP.md)
  2. [1.1] Fix login redirect bug (from TODO.md)
  3. [1.2] Add rate limiting to API (from TODO.md)
  4. [Project] Imported Backlog
  5. [2.1] Update deployment docs (from docs/notes.md)
  ...

Which items do you want to import into Track?
  - Numbers: 1,3,5
  - Ranges: 1-5
  - All: all
  - None: none
  - Exclude: all except 2,4
```

4. If the user's input cannot be parsed, re-prompt once with the syntax help above

#### Phase 8e: Apply selection

- `all` → keep everything, proceed
- `none` → delete all candidate files from `.track/tasks/` and `.track/projects/`
  that were created during this init run. Preserve pre-existing files and the
  README files
- Otherwise → delete only the unselected candidate task files created during this
  init run; delete a candidate project brief created during this run only if all
  of its tasks were also unselected
- If any imported candidate files remain after cleanup:
  1. Re-run `bash .track/scripts/track-validate.sh` and fix any errors
  2. Re-run `bash .track/scripts/track-todo.sh --local --offline`
  3. Record the result as: "Imported N tasks across M projects."
  4. Continue to Phase 10 after skipping Phase 9 onboarding creation
- If no imported candidate files remain, report: "Skipped import." and continue
  to Phase 9

### Phase 9: Onboarding fallback

If imports were kept from Phase 8, skip onboarding creation and continue to
Phase 10.

If no projects or tasks were imported (nothing found or user chose `none`),
onboarding is the fallback for both fresh installs and upgraded repos.

#### Step 1 — Ensure onboarding project and tasks exist

Before creating onboarding files, check whether these already exist:

- `.track/projects/1-onboarding.md`
- `.track/tasks/1.1-discover-and-plan.md`
- `.track/tasks/1.2-execute-migration.md`

Rules:

- If all three already exist, do not recreate them. Report that onboarding is
  already present and continue to Phase 10.
- If some exist and some are missing, preserve the existing files and create only
  the missing files.
- If none exist, create all of them.

Create `.track/projects/1-onboarding.md` if missing:

```markdown
# Onboarding

## Goal
Get Track working with your existing workflow by discovering what tools you use
and importing your tasks and projects.

## Why Now
Track was just initialized — importing existing work prevents a cold start and
teaches the Track workflow by doing.

## In Scope
- Discovering what the user currently uses for task management
- Building a migration plan
- Executing the migration

## Out Of Scope
- Ongoing sync between Track and external tools
- Migrating completed/archived items

## Shared Context
This project was auto-created during /track:init as a guided onboarding.
The first task doubles as a tutorial — it teaches the Track workflow while
accomplishing real work.

## Dependency Notes
None.

## Success Definition
Active tasks and projects from the user's current system are represented in .track/.

## Candidate Task Seeds
- Discover current tools and plan migration
- Execute the migration
```

Create `.track/tasks/1.1-discover-and-plan.md` if missing:

```yaml
---
id: "1.1"
title: "Discover current workflow and plan migration"
status: todo
mode: plan
priority: high
project_id: "1"
created: {today YYYY-MM-DD}
updated: {today YYYY-MM-DD}
depends_on: []
files:
  - ".track/plans/**"
pr: ""
---

## Context

This is your first Track task — it also serves as a tutorial for using Track
with Conductor.

When working this task, follow these steps:

1. Ask the user: "What are you currently using to manage tasks or projects?"
   Present these options:
   - **Linear** — we can connect via the Linear API
   - **Jira** — we can import via the Jira REST API
   - **Notion** — we can pull from Notion databases (MCP connector available)
   - **Notes** (Apple Notes, markdown files, paper) — tell us where they are
   - **Nothing** — no problem, we'll help you create your first real tasks
   - **Other** — tell us what you use

2. Based on the answer, ask follow-up questions to gather everything needed:

   | Tool | Questions |
   |------|-----------|
   | Linear | API key? Team name? Which projects to import? |
   | Jira | Instance URL? API token? Email? Project key(s)? |
   | Notion | Which database or page contains tasks? |
   | Notes | File paths or directory? What format? |
   | Nothing | What are you working on right now? What's most urgent? |
   | Other | What tool? Does it have an API or export? |

3. Record all answers in this task's ## Notes section as you go.

4. Write a migration plan to `.track/plans/onboarding-plan.md` with:
   - What tool the user uses
   - What data will be imported (projects, tasks, statuses)
   - Connection approach (API, file parsing, manual entry)
   - Step-by-step migration procedure

5. Present the plan to the user for approval. Iterate if they want changes.

6. Once approved, update the plan file status to "approved" and this task is done.

## Acceptance Criteria
- [ ] User's current tool identified
- [ ] All connection details gathered (API keys, paths, etc.)
- [ ] Migration plan written to .track/plans/onboarding-plan.md
- [ ] Plan approved by user

## Notes
Auto-created during /track:init onboarding.
```

Create `.track/tasks/1.2-execute-migration.md` if missing:

```yaml
---
id: "1.2"
title: "Execute migration from current tools"
status: todo
mode: implement
priority: high
project_id: "1"
created: {today YYYY-MM-DD}
updated: {today YYYY-MM-DD}
depends_on:
  - "1.1"
files:
  - ".track/tasks/**"
  - ".track/projects/**"
pr: ""
---

## Context

Execute the migration plan written in task 1.1. The plan is at
`.track/plans/onboarding-plan.md`.

Read the plan, then:
1. Connect to the user's tool using the details gathered in 1.1
2. Import projects as Track project briefs in .track/projects/
3. Import tasks as Track task files in .track/tasks/
4. Run validation and regenerate TODO.md
5. Present results to the user

If the user chose "Nothing" in task 1.1, help them create their first real
project and tasks using /track:create or /track:decompose.

## Acceptance Criteria
- [ ] All items from migration plan imported
- [ ] track-validate.sh passes
- [ ] TODO.md reflects imported state
- [ ] User confirms the import looks correct

## Notes
Auto-created during /track:init onboarding.
```

### Phase 10: Verify and hand off

1. Run `bash .track/scripts/track-validate.sh`
2. Run `bash .track/scripts/track-todo.sh --local --offline`
3. Report what was created, what was reused, and any warnings
4. Show exactly one closing message from the matrix below. Do not invent a
   custom summary when one of these cases applies.

#### Closing message matrix

If mode is `fresh-init` and imports were kept from Phase 8, display:

```
Track is ready! You imported N tasks across M projects.

To start working a task:
  1. Open a new workspace in Conductor
  2. Type: do task @{first available task ID}
  3. Hit Enter

Use /track:create to add more tasks, or /track:decompose to break a goal
into tasks. Your TODO.md has the full picture. Happy tracking!
```

If mode is `fresh-init` and no imports were kept and onboarding files were
created during this run, display:

```
Track is ready! Here's how to start your first task:

  1. Open a new workspace in Conductor
  2. Type: do task @1.1
  3. Hit Enter

Conductor will detect the task and walk you through it. The task will:
  - Create a branch and open a draft PR (this is how Track tracks progress)
  - Ask you about your current workflow tools
  - Build a migration plan for you to approve

After task 1.1 merges, task 1.2 will import your data.

Your TODO.md has the full picture. Happy tracking!
```

If mode is `fresh-init` and no imports were kept and onboarding already existed,
display:

```
Track is ready! No importable markdown was kept, and onboarding was already
present.

To continue, open a new workspace in Conductor and start with task @1.1.
Your TODO.md has the full picture. Happy tracking!
```

If mode is `upgrade-continue` and imports were kept from Phase 8, display:

```
Track is upgraded and ready! You imported N tasks across M projects.

To start working a task:
  1. Open a new workspace in Conductor
  2. Type: do task @{first available task ID}
  3. Hit Enter

Use /track:create to add more tasks, or /track:decompose to break a goal
into tasks. Your TODO.md has the full picture. Happy tracking!
```

If mode is `upgrade-continue` and no imports were kept and onboarding files were
created during this run, display:

```
Track is upgraded and ready! No importable markdown was kept, so onboarding was
created.

To continue, open a new workspace in Conductor and start with task @1.1.
Your TODO.md has the full picture. Happy tracking!
```

If mode is `upgrade-continue` and no imports were kept and onboarding already
existed, display:

```
Track is upgraded and ready! No importable markdown was kept, and onboarding was
already present.

To continue, open a new workspace in Conductor and start with task @1.1.
Your TODO.md has the full picture. Happy tracking!
```

## Rules

- Never overwrite existing files without asking unless this skill explicitly says
  to refresh scaffolded installed files in `.track/scripts/` or `.github/workflows/`
- Always read scaffold files from `${CLAUDE_SKILL_DIR}/scaffold/` — do not
  hardcode scaffold contents
- Make all scripts executable after copying
- Ensure `.track/` exists before running validation
- Preserve existing user-authored Track content
- Prefer repairing missing Track structure over duplicating it on reruns

## Do Not Prematurely Conclude

- Do not report success after upgrading scripts, workflows, or config alone
- Do not say "no further action needed" before the active mode reaches Phase 10
- Do not stop at the first local maximum because validation happens to pass after
  Phase 7
- Existing `.track/` state is not a reason to skip import or onboarding; it is
  only a reason to avoid duplicating first-time scaffolding
- If the user invoked `/track:init` and did not abort, complete the init flow
