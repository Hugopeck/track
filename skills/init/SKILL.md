---
name: init
description: |
  Set up Track from scratch. Scaffold everything an adopting repo needs —
  directories, scripts, CI workflows, and the CLAUDE.md protocol section — then
  create a first project to make the system immediately useful. Handle upgrades
  gracefully.
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

`/track:init` sets up Track in the current repository. Track is a git-native task
coordination system that uses `.track/` markdown files, bash scripts, and GitHub PR
state for task management.

## Scaffold Location

All scaffold files live in `${CLAUDE_SKILL_DIR}/scaffold/`. This directory contains
the canonical copies of everything that gets installed into the adopting repo.

## Initialization Steps

### Phase 1: Check existing state

1. Check if `.track/` already exists
   - If yes, ask the user: "Track is already set up. Upgrade scripts and workflows only, or abort?"
   - If upgrading, skip to Phase 3 (only update scripts and workflows)
   - If aborting, stop
2. Check if `scripts/track-common.sh` exists — warn if other track scripts exist without `.track/`

### Phase 2: Create .track/ directory

1. Read `${CLAUDE_SKILL_DIR}/scaffold/track/README.md` and write it to `.track/README.md`
2. Read `${CLAUDE_SKILL_DIR}/scaffold/track/projects/README.md` and write it to `.track/projects/README.md`
3. Create `.track/tasks/` directory (create a `.gitkeep` if empty)

### Phase 3: Install scripts

1. Create `scripts/` directory if it doesn't exist
2. For each script in `${CLAUDE_SKILL_DIR}/scaffold/scripts/`:
   - Read the scaffold version
   - Write to `scripts/{filename}`
   - Make executable with `chmod +x`
3. Scripts to install:
   - `track-common.sh`
   - `track-validate.sh`
   - `track-todo.sh`
   - `track-pr-lint.sh`
   - `track-complete.sh`

### Phase 4: Install GitHub workflows

1. Create `.github/workflows/` directory if it doesn't exist
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

### Phase 6: Update .gitignore

1. Read `.gitignore` (or create if absent)
2. If `TODO.md` is not already listed, append it

### Phase 7: Update CLAUDE.md

1. Read `CLAUDE.md` (or create if absent)
2. Check if it already contains a `## Track` section
3. If not, read `${CLAUDE_SKILL_DIR}/scaffold/CLAUDE_TRACK_SECTION.md` and append it to `CLAUDE.md`
4. If yes, ask user whether to replace the existing Track section

### Phase 8: Create first project

1. Ask the user: "What is your first project called? (e.g., 'API migration', 'Auth rewrite')"
2. Generate a project slug from the name (lowercase, hyphens)
3. Create `.track/projects/1-{slug}.md` with the required sections from the project brief contract:
   - `# {Project Name}`
   - `## Goal`
   - `## Why Now`
   - `## In Scope`
   - `## Out Of Scope`
   - `## Shared Context`
   - `## Dependency Notes`
   - `## Success Definition`
   - `## Candidate Task Seeds`
4. Fill in what you can from the user's description; leave placeholder text for sections that need human input

### Phase 9: Verify

1. Run `bash scripts/track-validate.sh`
2. Run `bash scripts/track-todo.sh --local --offline`
3. Report what was created and any warnings

## Rules

- Never overwrite existing files without asking
- Always read scaffold files from `${CLAUDE_SKILL_DIR}/scaffold/` — do not hardcode content
- Make all scripts executable after copying
- The `.track/` directory must exist before running validation
