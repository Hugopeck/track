# AGENTS.md

Shared repository instructions for OpenCode, Codex CLI, and other agentic coding tools.

OpenCode reads this file automatically at the repo root. This repo also ships an `opencode.json` that adds `CLAUDE.md` as supplemental detail so we can reuse the deeper repo notes without duplicating them here.

## Project Context

This is the Track repo. Track is a git-native task coordination system distributed as markdown skills and bash scripts. There is no build step or runtime app in this repo.

## Commands

```bash
# Run all tests
bash tests/run-all.sh

# Run a single test
bash tests/test-validate.sh

# Validate .track/ state
bash .track/scripts/track-validate.sh

# Regenerate Track views
bash .track/scripts/track-todo.sh              # default: origin/main + live PR data
bash .track/scripts/track-todo.sh --local      # local working tree
bash .track/scripts/track-todo.sh --offline    # skip GitHub PR lookup

# Test the Claude Code plugin locally
claude --plugin-dir .
```

## Architecture

Track has two layers:

1. **Skills** (`skills/`) — markdown protocols that teach agents the Track workflow.
2. **Scripts** (`.track/scripts/`) — bash enforcement scripts that validate task files, generate `BOARD.md`, `TODO.md`, and `PROJECTS.md`, lint PRs, and handle post-merge completion.

### Dual-Copy Scripts

Scripts exist in two identical locations:

- `.track/scripts/` — used by this repo's own `.track/`
- `skills/init/scaffold/track/scripts/` — copied into adopting repos by `/track:init`

When a script changes, mirror the same change in both locations.

### Key Files

- `.claude-plugin/plugin.json` — plugin manifest and released version
- `skills/init/scaffold/` — scaffold copied into adopting repos by `/track:init`
- `skills/init/scaffold/TRACK_PROTOCOL_SECTION.md` — canonical Track protocol shared by `CLAUDE.md` and `AGENTS.md`
- `skills/init/scaffold/CLAUDE_TRACK_SECTION.md` — the rendered Track section appended to adopting repos' `CLAUDE.md`
- `skills/work/SKILL.md` — the core workflow protocol
- `.track/scripts/track-common.sh` — shared YAML parser and script helpers

## Working Rules

- Keep changes tightly scoped to the requested task.
- Preserve the required protocol sections inside existing `SKILL.md` files.
- Do not change the released version in `.claude-plugin/plugin.json` manually.
- Prefer updating shared repo guidance once and reusing it across agent platforms.

## Conventional Commits

PR titles must follow conventional commits:

```text
type(scope): description
```

Common scopes: `skills`, `scripts`, `init`, `work`, `create`, `decompose`, `validate`, `todo`

Use `feat` for user-facing capability, `fix` for bug fixes, `docs` for documentation, `refactor` for internal code changes, `test` for test updates, `ci` for workflow changes, and `chore` for maintenance.

## Versioning

- Version lives in `.claude-plugin/plugin.json`
- `release-please` handles version bumps, changelog updates, and GitHub releases on merge to `main`
- `feat` triggers a minor bump, `fix` and `docs` trigger a patch bump, and `!` triggers a major bump

<!-- TRACK:START -->
## Track — Task Coordination

Track is a git-native coordination system. It is the source of truth for task state, task ownership, and task history. Follow its conventions and it keeps everything organized. The protocol below is both reference and guide.

Projects and tasks live in `.track/`. `TODO.md` is the generated shared view of current work.

### Layout
- `.track/projects/{project_id}-{slug}.md` — project briefs
- `.track/tasks/{task_id}-{slug}.md` — flat task files
- `.track/plans/{slug}.md` — short-lived plan documents (auto-expire after 7 days)
- `.track/scripts/` — bash enforcement scripts (managed by Track)
- `TODO.md` — generated view; gitignored and never canonical

### Task Format

```yaml
---
id: "{project_id}.{task_id}"
title: "One-line objective"
status: todo
mode: implement
priority: high
project_id: "{project_id}"
created: YYYY-MM-DD
updated: YYYY-MM-DD
depends_on: []
files: []
pr: ""
---

## Context
What needs to happen and why.

## Acceptance Criteria
- [ ] Primary outcome

## Notes
Append-only log.
```

### Fields
- `status`: `todo | active | review | done | cancelled`
- `mode`: `investigate | plan | implement`
- `priority`: `urgent | high | medium | low`
- `project_id`: filename-derived project identifier from `.track/projects/`
- `depends_on`: blocking task IDs
- `files`: glob patterns for files the task expects to modify
- `pr`: optional on raw task files; populated on `done` for historical traceability
- `cancelled_reason`: required when `status: cancelled`

### Raw vs Effective Status
- Raw status is the `status:` field stored in the task file
- Effective status is what `TODO.md` shows
- If raw status is `done` or `cancelled`, effective status matches it
- Otherwise, an open draft PR linked by `Track-Task`, `track:{id}`, title ID, or `task/{id}-{slug}` makes the task effectively `active`
- Otherwise, an open ready-for-review PR linked by `Track-Task`, `track:{id}`, title ID, or `task/{id}-{slug}` makes the task effectively `review`
- Otherwise, effective status is `todo`

### Agent Protocol (primary)

1. Read `TODO.md` for the execution queue and `BOARD.md` for project context. Pick a `todo` task or resume an `active` one.
2. Check `files:` overlap against tasks already shown as `active` / `review` — do not touch files owned by another in-progress task.
3. Create a branch or use the current one.
4. Open a **draft PR** to start work. No PR = not started.
5. Prefer a PR title that includes the task ID: `[{id}] Title` or `({id}) Title`.
6. Always add `Track-Task: {id}` to the PR body. This is the primary linkage. Optional label: `track:{id}`.
7. If the PR also completes another small task as a drive-by, add `Also-Completed: {id}` to the PR body. On merge, Track marks those tasks done too.
8. If `gh` auth fails or PR creation fails, **stop and surface the error.**
9. Implement. When ready, mark the PR ready for review.

`BOARD.md`, `TODO.md`, and `PROJECTS.md` are generated — edit task files in `.track/tasks/`, not the generated views directly.

`/track:work` contains the full protocol with edge cases. Use it when this section is insufficient.

### Starting Work (details)
1. Read the task's `## Context` and `## Notes` — previous sessions may have left important context
2. Pick work that has no unresolved `depends_on` blockers
3. If the task's mode is `investigate` or `plan`, focus on understanding and documenting findings before writing implementation code
4. If acceptance criteria seem incomplete, update them before starting
5. Use a dedicated worktree or branch per task when possible

### Working a Task (Provisional PR lifecycle)
1. Create a branch from `main` (or use the current branch)
2. First commit updates the task file only:
   - set raw `status: active`
   - update `updated:`
3. Push and open a **draft PR** immediately
   - Always include `Track-Task: {id}` on the first line of the PR body
   - PR title must include the task ID: `[4.1] Title` or `feat(scope): (4.1) Title`
   - Optional label: `track:{id}`
   - CI resolves the task from body, labels, title, then branch name
4. Do the implementation work with as many commits as needed
5. When ready for review:
   - set raw `status: review`
   - update `updated:`
   - mark the PR ready for review
6. When the PR merges, the post-merge workflow writes `status: done`, `pr:`, and `updated:` on `main`

Example PR linkage:

```text
Branch: any-branch-name
Title: feat(skills): [7.2] create /track:test skill
Body: Track-Task: 7.2
```

Example drive-by completion (primary task 7.1, also resolved 7.2):

```text
Branch: task/7.1-test-runner
Title: feat(tests): [7.1] unified test runner
Body:
Track-Task: 7.1
Also-Completed: 7.2
```

### Creating a Task
- Every task belongs to a project and uses `project_id`
- Open work must use dotted IDs like `1.1`
- Put scope and success definition in the project brief, not the task

### Decomposing a Goal
- Analyze module boundaries first
- Create one task per independent unit with non-overlapping `files:` scopes
- Use `depends_on` to sequence foundation work before integration work
- Prefer small reviewable PRs over multi-goal tasks

### Saving Plans
When any planning, investigation, or design work produces a plan, **automatically save it** to `.track/plans/`. Do not wait for the user to ask — persistence is the default.
- Filename: `{task_id}-{slug}.md` when linked to a task, or `{slug}.md` otherwise
- Add YAML frontmatter with `title`, `created` (today's date), and optionally `task_id`/`project_id`
- The body is freeform — paste the plan content as-is, no reformatting needed
- Plans auto-expire 7 days after `created`; update the date to keep one longer

### Regenerating `TODO.md`
After creating, updating, cancelling, or completing tasks, regenerate the shared view:

```shell
bash .track/scripts/track-todo.sh
```

Useful modes:

```shell
bash .track/scripts/track-todo.sh --local
bash .track/scripts/track-todo.sh --offline
```

### Validation
Run Track validation after changing task files, project briefs, or task lifecycle scripts:

```shell
bash .track/scripts/track-validate.sh
```

### Working Principles

- **Investigate before implementing.** When a task has mode `investigate` or `plan`, explore the codebase thoroughly before writing code. Read related files, check for existing patterns, understand dependencies. Only move to implementation when you have a clear path.
- **Update task files as you work, not after.** When you discover new context, constraints, or dead ends, append to the task's `## Notes` immediately. Future sessions depend on this context.
- **Check for conflicts before starting.** Scan active and review tasks for overlapping `files:` globs. Starting work on contested files creates merge conflicts.
- **Scope aggressively.** If a task grows beyond its acceptance criteria, split the new work into a separate task rather than expanding the current one.
- **Let the system track status.** Don't manually update status fields to show progress. Open a draft PR — Track knows you're active. Mark it ready for review — Track knows you're in review. The PR lifecycle is the status lifecycle.
- **Validate early and often.** Run `bash .track/scripts/track-validate.sh` after every task file change. Errors caught locally are cheap; errors caught in CI block the team.
<!-- TRACK:END -->
