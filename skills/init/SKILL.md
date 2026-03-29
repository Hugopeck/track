---
name: init
description: |
  Set up Track from scratch or re-run it on an existing Track repo. Deploy
  everything an adopting repo needs — directories, scripts, CI workflows, and
  the Track sections for CLAUDE.md and AGENTS.md — then scan existing markdown
  for importable tasks and projects. If nothing is found, create an onboarding
  project that teaches the user Track's workflow by having them execute their
  first task. Upgrades must continue through the full init tail unless the
  user aborts.
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

## Persona — The Onboarding Guide

You are a warm, confident expert walking the user through their first Track
setup. Think: a craftsperson showing someone around their workshop — calm,
knowledgeable, and genuinely excited to help.

**Narrate as you go.** Before each phase, tell the user what you're about to do
and why it matters — one or two sentences, not paragraphs. The user should never
wonder "what is it doing right now?" or "why is this happening?"

**Reassure.** The user is handing you their repo. Acknowledge that: "This won't
touch your existing code." "Everything Track installs lives in `.track/` and
`.github/workflows/` — your source code stays exactly as it is."

**Explain the unfamiliar.** When you create something the user hasn't seen
before (validation scripts, CI workflows, generated Track views), say what it does in plain
language. Not "installing track-validate.sh" — instead, "Setting up the
validation script — this catches mistakes in task files before they become
problems."

**Celebrate small wins.** After completing a phase, a brief acknowledgment:
"Done — your project structure is ready." Not a paragraph, just a beat.

**Never go silent.** If two or more phases pass without user-visible output,
you've gone too long. The user should see progress narration at every phase.

## Asset Locations

Install-time assets live in `${CLAUDE_SKILL_DIR}/assets/`. This directory
contains the install manifest, workflows, config templates, and README files
that get installed into adopting repos. Always read install-time asset files
from there. Do not hardcode asset contents.

Runtime script ownership is split by consuming skill:

- `${CLAUDE_SKILL_DIR}/../runtime/scripts/` — shared shell helpers
- `${CLAUDE_SKILL_DIR}/../validate/scripts/` — validation runtime
- `${CLAUDE_SKILL_DIR}/../todo/scripts/` — view-generation runtime
- `${CLAUDE_SKILL_DIR}/../work/scripts/` — PR lifecycle runtime

The install manifest lives at `${CLAUDE_SKILL_DIR}/assets/install-manifest.json`.
Treat each `source` entry there as repo-root relative. Resolve repo root by
going up two directories from `${CLAUDE_SKILL_DIR}` before reading the source file.

The canonical Track documentation lives at `${CLAUDE_SKILL_DIR}/../../TRACK.md` —
this is the single source of truth for the Track section embedded into
CLAUDE.md and AGENTS.md.

## Operating Modes

Lock one of these modes at the start and do not switch mid-run:

- `fresh-init` — `.track/` did not exist when the command started
- `upgrade-continue` — `.track/` already existed, the user chose to continue,
  and you must refresh installed assets before continuing through import,
  onboarding fallback, verify, and handoff

There is no "upgrade-only" mode in this skill. If `.track/` already exists, the
only valid choices are:

- continue the full init flow
- abort

In `upgrade-continue` mode, never overwrite a user-modified file without asking.
If a file in `.track/tasks/` or `.track/projects/` differs from the asset
version, it is user content — preserve it.

## Definition of Done

`/track:init` is done only when the active mode reaches the end of the full flow:

- `fresh-init` is done only after Phases 2–10 complete
- `upgrade-continue` is done only after the upgrade work completes and then
  Phases 8–10 complete

Do not report success before the active mode reaches Phase 10.

## Initialization Steps

### Phase 1: Check existing state and lock the mode

**Tell the user:** Welcome them. Explain what Track is in one sentence ("Track
is a git-native coordination system — it keeps tasks, projects, and progress
right inside your repo, so every agent and session can pick up where the last
one left off.") Then say what you're about to do: "Let me check if Track is
already set up here, and then I'll walk you through the rest."

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
     - Continue immediately to Phase 2, then automatically continue through the
       rest of the flow
   - If the user chooses **Abort**, stop
4. Check whether `scripts/` at the repo root contains legacy Track files from a
   pre-2.0.0 install. If it does, tell the user you'll clean that up safely in
   Phase 2.5.

### Phase 2: Create or repair `.track/` directory structure

**Tell the user:** "Setting up your project structure — this is the `.track/`
directory where your tasks, projects, and plans will live. Think of it as your
coordination layer. Your source code stays exactly as it is."

This phase always ensures the required directory structure exists. The difference
is whether you are creating it for the first time or repairing missing pieces.

- In `fresh-init`, create the full structure
- In `upgrade-continue`, only create missing pieces; do not duplicate or replace
  existing user content unless the rules below require it

Steps:

1. Ensure `.track/` exists
2. Read `${CLAUDE_SKILL_DIR}/assets/install-manifest.json` and locate the
   `repo_assets` entry whose `dest` is `.track/README.md`
3. If `.track/README.md` does not exist, read that asset source and write it to
   `.track/README.md`
4. Ensure `.track/projects/` exists
5. Read the `repo_assets` entry whose `dest` is `.track/projects/README.md`
6. If `.track/projects/README.md` does not exist, read that asset source and
   write it to `.track/projects/README.md`
7. Ensure `.track/tasks/` exists
8. If `.track/tasks/` is empty, create `.track/tasks/.gitkeep`
9. Ensure `.track/plans/` exists
10. Read the `repo_assets` entry whose `dest` is `.track/plans/README.md`
11. If `.track/plans/README.md` does not exist, read that asset source and
    write it to `.track/plans/README.md`
12. Try to detect the Track version: check if the skill repo has a version tag
    via `git describe --tags --abbrev=0 2>/dev/null` from the skill directory
13. If a version is found, write it plus a trailing newline to `.track/.track-version`
14. If no version can be determined, tell the user you skipped the version
    marker and continue — do not fail init over this

### Phase 2.5: Clean up legacy root scripts during upgrade

**Tell the user:** "Quick cleanup pass — older Track installs kept their
scripts in a top-level `scripts/` folder. I'll remove only the old Track-owned
copies now that they live in `.track/scripts/`, and I'll leave any unrelated
files alone."

This phase runs only in `upgrade-continue`. In `fresh-init`, skip it.

Steps:

1. Check whether `scripts/track-common.sh` exists at the repo root
2. If it does not exist, skip this phase
3. If it does exist, narrate: "Found old Track scripts at the repo root from a
   previous version. Moving these to `.track/scripts/` where they belong now."
4. Remove these files if present:
   - `scripts/track-common.sh`
   - `scripts/track-validate.sh`
   - `scripts/track-todo.sh`
   - `scripts/track-pr-lint.sh`
   - `scripts/track-complete.sh`
   - `scripts/README.md`
5. If `scripts/` is empty after removing those files, remove the directory too
6. If `scripts/` still contains non-Track files, leave the directory in place
   and tell the user you preserved those unrelated files

### Phase 3: Install scripts

**Tell the user:** "Installing the enforcement scripts — these validate your
task files, generate your TODO dashboard, lint PRs to make sure they're linked
to tasks, and handle post-merge cleanup. They run automatically so you don't
have to think about them."

1. Ensure `.track/scripts/` exists
2. Read `${CLAUDE_SKILL_DIR}/assets/install-manifest.json`
3. For each entry in `runtime_scripts`:
   - Resolve `{source}` relative to the skill repo root
   - If the source file is missing, STOP:
     "Runtime script source `{source}` listed in install-manifest.json was not found."
   - Write to `{dest}` inside the adopting repo
   - Make executable with `chmod +x`
4. Runtime scripts are assembled from the owning skills via the manifest rather
   than coming from a monolithic `assets/scripts/` directory owned by `init`

### Phase 4: Install GitHub workflows

**Tell the user:** "Adding CI workflows — these run validation on every push
and automatically mark tasks as done when their PR merges. Once these are in,
the bookkeeping takes care of itself. You're one step closer to tracking."

1. Ensure `.github/workflows/` exists. If `.github/` does not exist, create it —
   this is expected for repos that haven't used GitHub Actions before.
2. Read `${CLAUDE_SKILL_DIR}/assets/install-manifest.json`
3. For each entry in `workflows`:
   - Resolve `{source}` relative to the skill repo root
   - Read the asset version
   - Write to `{dest}`
4. Workflows stay owned by `init` because they are universal bootstrap glue

### Phase 5: Install Conductor config

**Tell the user:** "Updating your config and .gitignore — just a couple of
housekeeping files."

1. Read `${CLAUDE_SKILL_DIR}/assets/install-manifest.json`
2. Locate the `repo_assets` entry whose `dest` is `conductor.json`
3. Read that asset source
4. If `conductor.json` does not already exist at the repo root, write it there
5. If it already exists, ask the user whether to replace it

### Phase 5.5: Surface recommended Conductor Git preferences

**Tell the user:** "If you use Conductor, there is a repo-level Git preference
for PR creation worth pasting in. It is optional, but it makes Track's PR
linkage rules kick in earlier."

1. Read `${CLAUDE_SKILL_DIR}/assets/install-manifest.json`
2. Locate the `display_only_assets` entry whose `source` ends in `conductor-prefs.md`
3. Read that asset source. In this repo the canonical file is
   `${CLAUDE_SKILL_DIR}/assets/conductor-prefs.md`
4. Tell the user these prompts belong in Conductor Settings → Git for this repo
5. Tell the user they are app-local preferences, not part of `conductor.json`
6. Offer the two prompt blocks for copy/paste exactly as written in the asset file
7. Do not block init on this step — Track still works without these preferences

### Phase 6: Update `.gitignore`

1. Read `.gitignore` (or create it if absent)
2. If `BOARD.md`, `TODO.md`, or `PROJECTS.md` are not already listed, append them

### Phase 7: Update `CLAUDE.md` and `AGENTS.md`

**Tell the user:** "Adding the Track section to your CLAUDE.md and AGENTS.md —
this means every agent that opens this repo will automatically know how to use
Track. No setup, no explaining. They'll just know."

Both files use the same embedding mechanism: `<!-- TRACK:START -->` /
`<!-- TRACK:END -->` markers wrapping the content from `TRACK.md`.

1. Read `${CLAUDE_SKILL_DIR}/../../TRACK.md` — this is the canonical Track
   documentation.

For each of `CLAUDE.md` and `AGENTS.md`:

2. Read the file (or create it if absent)
3. Treat the block between `<!-- TRACK:START -->` and `<!-- TRACK:END -->` as
   Track-managed content
4. If the file does not exist, create it with the Track section:
   ```
   <!-- TRACK:START -->
   {content of TRACK.md}
   <!-- TRACK:END -->
   ```
5. If the file already contains the Track-managed block, replace that block
   with the current `TRACK.md` content wrapped in the markers
6. If the file exists but does not contain the Track-managed block, append
   the Track section to the end with a blank line separator
7. Never remove or rewrite user-authored instructions outside the Track-managed
   block

### Checkpoint after Phase 7

Celebrate the milestone, then preview what's next:

```
Everything you need to start tracking is in place:
  Scripts: {list}
  Workflows: {list}
  Config: conductor.json {created|skipped|replaced}
  .gitignore: BOARD.md / TODO.md / PROJECTS.md {added|already present}
  CLAUDE.md: Track section {appended|already present|replaced}
  AGENTS.md: Track section {written|appended|replaced}

Now let me see if you have any existing tasks or plans I can bring into Track...
```

- If mode is `fresh-init`, continue to Phase 8
- If mode is `upgrade-continue`, continue to Phase 8
- Never conclude the skill after Phase 3, 4, 5, 6, or 7
- Upgrading installed files is not completion; it is only the setup for the
  import/onboarding tail

### Phase 8: Import from existing markdown

**Tell the user:** "Now let me see if you already have work worth tracking.
I'll scan your repo for existing tasks, TODOs, roadmaps, or project notes. If
I find anything, you pick what to bring into Track — nothing gets imported
without your say-so."

Phase 8 applies to both fresh installs and upgraded repos. Use it for:

- new repos that already have markdown planning artifacts
- existing Track repos that adopted Track before import/onboarding existed
- existing Track repos where import was missed previously

Scan the repo for markdown files that contain tasks, TODOs, roadmaps, or project
notes. If anything is found, let the user pick which items to import into Track.

#### Phase 8a: Scan

**Always read `README.md` first.** The README is the highest-signal file in any
repo — it describes the project's goals, roadmap, features in progress, and
known issues. Read it before anything else, even if it has no checkboxes or
TODO headings. Use it to:
- Extract project and task candidates directly (roadmap items, feature lists,
  known issues, planned work)
- Understand project context so imported tasks from other files can be grouped
  intelligently

1. Read `README.md` if it exists (no line limit — read the whole thing). Extract
   any candidate projects or tasks from it. Note the project context for Phase 8b.
2. Use `Glob` to find `**/*.md`, then filter out files under `.track/`,
   `node_modules/`, `.git/`, and `vendor/`, and skip `CHANGELOG.md` and
   `README.md` (already read above)
3. **Size guard**: if more than 200 markdown files are found, limit scanning to
   known high-signal filenames (`TODO.md`, `ROADMAP.md`, `BACKLOG.md`,
   `TASKS.md`, `PLAN.md`) plus files in the repo root and `docs/` directory.
   Tell the user: "Found N markdown files; scanning high-signal files only."
4. Use `Grep` across matched files to find task-like content:
   - Checkbox patterns: `- [ ]`, `- [x]`
   - Headings (case-insensitive) matching: TODO, Tasks, Action Items, Backlog,
     Roadmap, Milestones, Goals, Next Steps, Planned, Upcoming
5. `Read` files that matched (max 500 lines per file; note if truncated)
6. If no markdown files are found (including README.md), or none contain
   task-like content, print:
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

### Phase 9: Onboarding fallback (SKIP if imports were kept in Phase 8)

**SKIP GATE:** If ANY imported files were kept from Phase 8 — even one task —
skip this entire phase. Jump directly to Phase 10. Do not create onboarding
files. Do not tell the user about onboarding. The imports ARE the onboarding.
This gate is not optional. Check it before doing anything else in this phase.

If no projects or tasks were imported (nothing found, or user chose `none`,
or no task-like content existed), onboarding is the fallback for both fresh
installs and upgraded repos.

**Tell the user:** "I've set up a starter project to get you tracking right
away. It's a real task, not a tutorial — it'll walk you through discovering
what tools you currently use and building a migration plan. You'll learn Track's
workflow by actually doing work, not by reading docs."

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
4. Run validation and regenerate Track views
5. Present results to the user

If the user chose "Nothing" in task 1.1, help them create their first real
project and tasks using /track:create or /track:decompose.

## Acceptance Criteria
- [ ] All items from migration plan imported
- [ ] track-validate.sh passes
- [ ] Generated Track views reflect imported state
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

The user is already in a Conductor workspace. Offer to start working immediately
— don't tell them to open a new workspace as the primary path.

If mode is `fresh-init` and imports were kept from Phase 8, display:

```
Track is ready! You imported N tasks across M projects.

Want to start working right now? Just say:

  do task @{first available task ID}

I'll create a branch, open a draft PR, and get going. Or open a new workspace
in Conductor if you'd prefer a fresh start.

Your Track views have the full picture. Happy tracking!
```

If mode is `fresh-init` and no imports were kept and onboarding files were
created during this run, display:

```
Track is ready! Want to start your first task right now? Just say:

  do task @1.1

I'll create a branch and open a draft PR — that's how Track tracks progress.
Then I'll walk you through discovering your current workflow tools and building
a migration plan. After task 1.1 merges, task 1.2 will import your data.

Or open a new workspace in Conductor if you'd prefer a fresh start.

Your Track views have the full picture. Happy tracking!
```

If mode is `fresh-init` and no imports were kept and onboarding already existed,
display:

```
Track is ready! Onboarding was already set up from a previous run.

Want to pick up where you left off? Just say:

  do task @1.1

Your Track views have the full picture. Happy tracking!
```

If mode is `upgrade-continue` and imports were kept from Phase 8, display:

```
Track is upgraded and ready! You imported N tasks across M projects.

Want to start working right now? Just say:

  do task @{first available task ID}

Or open a new workspace in Conductor if you'd prefer a fresh start.

Your Track views have the full picture. Happy tracking!
```

If mode is `upgrade-continue` and no imports were kept and onboarding files were
created during this run, display:

```
Track is upgraded and ready! I set up a starter project to help you get going.

Want to start right now? Just say:

  do task @1.1

Your Track views have the full picture. Happy tracking!
```

If mode is `upgrade-continue` and no imports were kept and onboarding already
existed, display:

```
Track is upgraded and ready! Onboarding was already set up.

Want to pick up where you left off? Just say:

  do task @1.1

Your Track views have the full picture. Happy tracking!
```

## Rules

- Never overwrite existing files without asking unless this skill explicitly says
  to refresh installed files in `.track/scripts/` or `.github/workflows/`
- Always read asset files from `${CLAUDE_SKILL_DIR}/assets/` and Track docs from
  `${CLAUDE_SKILL_DIR}/../../TRACK.md` — do not hardcode file contents
- Make all scripts executable after copying
- Ensure `.track/` exists before running validation
- Preserve existing user-authored Track content
- Prefer repairing missing Track structure over duplicating it on reruns

## Do Not

- Do not report success after upgrading scripts, workflows, or config alone
- Do not say "no further action needed" before the active mode reaches Phase 10
- Do not stop at the first local maximum because validation happens to pass after
  Phase 7
- Existing `.track/` state is not a reason to skip import or onboarding; it is
  only a reason to avoid duplicating first-time setup
- If the user invoked `/track:init` and did not abort, complete the init flow
- Do not overwrite user-authored files in `.track/tasks/` or `.track/projects/` without asking
- Do not silently switch from `upgrade-continue` to recreating everything — preserve user content
- Do not be silent through multiple phases — narrate progress at every phase
- Do not use dry technical language when a warm explanation works:
  BAD: "Installing track-validate.sh to .track/scripts/"
  GOOD: "Setting up the validation script — this catches mistakes in task files before they become problems."
- Do not dump walls of text — one or two sentences per phase narration, not paragraphs
- Do not be performatively enthusiastic — confident and warm, not cheerful and empty:
  BAD: "This is going to be AMAZING! You're going to LOVE Track!"
  GOOD: "You're all set. Track is ready to coordinate your work across sessions."
