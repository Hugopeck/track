# AGENTS.md

Shared repository instructions for Claude Code, OpenCode, Codex CLI, and other agentic coding tools.

## Project Context

This is the Track skill project. Track is a git-native task coordination system distributed as agent skills and bash scripts. No build step, no runtime — the project is markdown skills and bash enforcement scripts.

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
```

## Architecture

Track has two layers:

1. **Skills** (`skills/`) — markdown protocols that teach agents the Track workflow. Each skill has a `SKILL.md` with YAML frontmatter (name, description, allowed-tools) and instructional content.
2. **Runtime scripts** (`skills/runtime/scripts/`, `skills/validate/scripts/`, `skills/todo/scripts/`, `skills/work/scripts/`) — bash enforcement scripts that validate task files, generate views, lint PRs, and handle post-merge completion.

### Repo Layout

This repo is a **skill project** (not a plugin). Skills are the content; plugins are a separate delivery mechanism.

- `TRACK.md` — canonical Track documentation (single source of truth, embedded into adopting repos)
- `skills/` — installable agent skills and support directories (only directories with `SKILL.md` are standalone skills)
- `skills/setup-track/assets/` — everything the setup-track skill deploys to adopting repos (scripts, workflows, config)
- `.track/` — Track dogfooding itself (scripts are symlinks to the owned runtime sources under `skills/`)
- `tests/` — test suite
- `tools/` — dev utility scripts
- `growth/` — marketing content

### Key Files

- `TRACK.md` — canonical Track documentation shared by `CLAUDE.md` and `AGENTS.md`
- `skills/work/SKILL.md` — the core workflow protocol (auto-loaded when `.track/` exists)
- `skills/runtime/scripts/track-common.sh` — shared YAML frontmatter parser and utility functions
- `tools/render-track-section.sh` — regenerates the Track section in this repo's `AGENTS.md`

### Skill Inventory

| Skill | Purpose |
|-------|---------|
| `work` | Core workflow protocol — reading state, picking work, PR lifecycle |
| `setup-track` | Deploy `.track/`, scripts, workflows, and Track sections into a new repo |
| `create` | Create tasks and projects |
| `decompose` | Break a goal into tasks with dependencies |
| `refresh-track` | Regenerate `BOARD.md`, `TODO.md`, and `PROJECTS.md` |
| `update-skills` | Self-update Track skills to latest version |

## Working Rules

- Keep changes tightly scoped to the requested task.
- Preserve the required protocol sections inside existing `SKILL.md` files.
- Prefer updating shared repo guidance once and reusing it across agent platforms.

## Conventional Commits

Every PR title **must** follow conventional commits — CI will reject it otherwise.

```
type(scope): description
```

| Type | When to use | Version bump |
|------|-------------|--------------|
| `feat` | New user-facing capability | minor |
| `fix` | Bug fix | patch |
| `docs` | Documentation only | patch |
| `refactor` | Code change that doesn't fix a bug or add a feature | patch |
| `test` | Adding or updating tests | — |
| `ci` | CI/workflow changes | — |
| `chore` | Maintenance (deps, config) | — |
| `perf` | Performance improvement | patch |
| `style` | Formatting, whitespace (no logic change) | — |
| `build` | Build system or external dependency changes | — |
| `revert` | Reverts a previous commit | patch |

Common scopes: `track`, `setup-track`, `skills`, `scripts`, `tests`, `docs`, `ci`

Scope should match a directory name or subsystem. Omitting scope is fine for cross-cutting changes.

```
BAD:  "Add E2E lifecycle test" (missing type prefix)
GOOD: "test: add E2E lifecycle test"
```

Breaking changes: add `!` after the scope (e.g. `feat(scripts)!: redesign validation`) — this triggers a **major** bump.

## Versioning

- **release-please** automates releases: on merge to main, it reads conventional commit prefixes, updates the version, generates `CHANGELOG.md`, and creates a GitHub release
- Config: `release-please-config.json` / `.release-please-manifest.json`
- `feat` → minor bump, `fix`/`docs` → patch bump, `!` → major bump
- `chore` and `ci` commits are hidden from the changelog

## Skill Protocol Structure

Every skill follows a strict protocol structure. When editing or creating skills, preserve these sections exactly:

1. **"What This Skill Owns"** — defines the skill's scope boundary. A skill must not act outside its ownership. If a step belongs to another skill, name it and stop.
2. **"Operating Modes"** — the skill locks into one mode at the start of a run and stays in it. Do not switch modes mid-execution.
3. **"Definition of Done"** — the skill is not done until every condition is met. Do not report success early. Validation must pass before any success message.
4. **"Closing Message Matrix"** — each mode has exactly one closing message template. Use it verbatim. Do not improvise, summarize, or add commentary beyond the template.
5. **"Do Not"** — hard constraints. These are not suggestions. Violating a "Do Not" rule is a bug, not a judgment call.

These sections are the enforcement layer that keeps the agent on protocol. Without them, skills drift into generic assistant behavior — summarizing instead of acting, skipping validation, reporting success prematurely, or exceeding scope.

When modifying a skill, do not weaken, remove, or soften these sections. If a new behavior is needed, add it to the appropriate section rather than working around it.

## Skill Writing Style

Skills are instructions to an LLM agent. Every word costs context window and shapes behavior. Write accordingly.

### Voice and Density

Use imperative voice. "Read the file." not "You should read the file." Hedging language ("consider", "you might want to", "it would be good to") is treated as optional by the agent — if it must happen, command it.

Cut to ~60% of first-draft word count. No filler ("In order to", "It is important that"), no preamble ("In this section, we will"), no restating what was just said. Dense prose models the output style you want — terse skills produce terse agent output.

### Structure

Number steps explicitly. Use half-steps (1.5, 4.75) to insert new phases without renumbering. Each step has one job. Separate steps with `---` horizontal rules.

Start every section with a one-sentence summary before detailed instructions. If the agent only reads the first line, it should still do roughly the right thing.

### Output Templates

For every output the skill produces, show one complete example with the exact format:

```
BAD:  "List each issue with its severity."
GOOD: "[CRITICAL] app/models/post.rb:42 — Race condition in status transition"
```

The agent pattern-matches examples more reliably than it follows descriptions of formats.

### Forced Classification

Wherever the agent needs judgment, give it 2-4 named categories and force a pick. No "maybe" bucket.

```
BAD:  "Evaluate the severity of each finding."
GOOD: "Classify each finding as AUTO-FIX or ASK. No other categories."
```

Without forced classification, agents default to "this might be an issue, consider looking into it."

### Anti-Patterns

For every important instruction, add 1-2 anti-patterns showing what the wrong version looks like. Use "BAD:", "Do NOT", or "Never" to mark them.

```
Never say "likely handled" or "probably tested" — verify or flag as unknown.
"This looks fine" is not a finding. Either cite evidence or flag as unverified.
```

LLMs have strong defaults (summarizing, hedging, being agreeable). Telling them what to do is not enough — explicitly block the behaviors you don't want.

### Escape Hatches

Every tool call, file read, or external dependency needs a failure path. Classify each as:
- **STOP** — cannot continue without this ("If the file cannot be read, STOP and report the error.")
- **SKIP** — nice-to-have, degrade gracefully ("If no PR exists: skip this step silently.")

Without explicit failure paths, the agent either halts the session or invents a workaround.

### Verification Requirements

For any claim about correctness, safety, or coverage — require evidence:

```
- Claim "this is safe" → cite the specific line proving safety
- Claim "tests cover this" → name the test file and method
- Cannot verify → flag as unknown (better than confabulating)
```

### Named Principles

If a concept applies in multiple places, give it a short name. Introduce it once with a full explanation. Reference it by name everywhere else. The agent will cite these names in output, which helps the user understand the reasoning.

### Mode Commitment

If the skill has modes that change behavior, include an explicit "do not drift" instruction. LLMs regress to the mean over long outputs — they soften aggressive positions and water down strong constraints. Counter this directly: "Once selected, commit fully. Do not silently drift toward a different mode."

### Calibration

When the agent must exercise judgment (severity, priority, whether something is worth flagging), give one concrete example at the exact threshold:

```
Calibration — this is the bar: [specific example at the boundary].
Things less consequential than this, skip.
```

The agent interpolates from the example better than from abstract criteria.

## Other Conventions

- Adopting repos are self-contained — they never depend on this skill project at runtime
- The skills teach agents the Track protocol; the scripts enforce it
- bash 3.2+ compatibility required (macOS default)
<!-- TRACK:START -->
## Track — Task Coordination

Track is a git-native coordination protocol. It is the source of truth for task state, task ownership, and task history. Track runs as markdown task files, bash scripts, git hooks, and GitHub workflows — no server, no binary, no always-on runtime.

Projects, tasks, plans, specs, and activity logs live in `.track/`. `TODO.md` is the generated shared view of current work.

### Layout
- `.track/projects/{project_id}-{slug}.md` — project briefs
- `.track/tasks/{task_id}-{slug}.md` — flat task files
- `.track/plans/{slug}.md` — short-lived plan documents (auto-expire after 7 days)
- `.track/specs/{slug}.md` — durable architecture, design, and interface specs
- `.track/events/log.jsonl` — append-only activity log written by hooks and lifecycle actions
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
- `status`: `todo | active | review | blocked | done | cancelled`
- `mode`: `investigate | plan | implement`
- `priority`: `urgent | high | medium | low`
- `project_id`: filename-derived project identifier from `.track/projects/`
- `depends_on`: blocking task IDs
- `files`: glob patterns for files the task expects to modify
- `pr`: optional on raw task files; populated on `done` for historical traceability
- `cancelled_reason`: required when `status: cancelled`
- `blocked_reason`: required when `status: blocked`

### Canonical Task Status
- `status:` in the task file is the canonical task status
- PR-driven lifecycle writes are owned by Track scripts and workflows, not manual frontmatter edits
- `bash .track/scripts/track-start.sh {id}` writes `status: active` and updates `updated:`
- `bash .track/scripts/track-ready.sh {id}` writes `status: review` and updates `updated:`
- The merged-PR completion flow writes `status: done`, `pr:`, and `updated:` on `main`
- `TODO.md` and related views use task state plus linked PR metadata to show current in-progress work; if task state and PR state drift, treat that as a sync bug and repair it with Track automation rather than hand edits

### Event Log and Attribution
- Track writes append-only activity events to `.track/events/log.jsonl`
- The wire format is defined in `.track/specs/event-contract.md`
- Core event types are `track.commit`, `track.pr.opened`, `track.pr.ready`, `track.pr.merged`, `track.task.started`, and `track.link`
- Untracked activity is first-class: an event may exist before it has a task attribution
- If work happened outside the normal task branch flow, ask `/track:work` to link the current branch to a task; this appends a `track.link` event for retroactive attribution

### Hooks and Automation
- `commit-msg` enforces conventional commit format locally
- `post-commit` writes `track.commit` events to the JSONL activity log and never blocks the commit
- `track-status-sync` maps same-repo PR lifecycle events to canonical task status updates before downstream checks run
- `Track Validate` and `Track PR Lint` run on PR updates and can also be called from the ordered status-sync workflow
- `track-complete` writes merged completion state, cascades dependency unblocks, and regenerates Track views
- `/track:setup-track` can also apply a GitHub Ruleset that requires `Track Validate`, `Track PR Lint`, and `conventional-commit-lint`; if strict required checks are enabled, the PR head must be up to date with `main` and the latest head commit must carry those exact check names
- Default allowed commit types: `feat`, `fix`, `docs`, `refactor`, `test`, `ci`, `chore`, `perf`, `style`, `build`, `revert`. Override per-repo via `.track/config.yml`:
  ```yaml
  commit_types:
    - feat
    - fix
    - custom-type
  ```

### Agent Protocol (primary)

1. Read `TODO.md` for the execution queue and `BOARD.md` for project context. Pick a `todo` task or resume an `active` one.
2. Check `files:` overlap against tasks already shown as `active` / `review` — do not touch files owned by another in-progress task.
3. Create a branch or use the current one.
4. Run `bash .track/scripts/track-start.sh {id}` before opening a draft PR so Track, validation, and the task file stay aligned.
5. Open a **draft PR** to start work. No PR = not started.
6. Prefer a conventional-commit PR title that includes the task ID: `type(scope): [id] short description`.
7. If the branch is not named `task/{id}-{slug}`, put `Track-Task: {id}` on line 1 of the PR body. On task branches, adding `Track-Task:` is still preferred. Optional label: `track:{id}`.
8. Use `Also-Completed: {id}` only for fully resolved drive-by tasks (max 2). On merge, Track marks those tasks done too.
9. If `gh` auth fails or PR creation fails, **stop and surface the error.**
10. Implement. When ready, run `bash .track/scripts/track-ready.sh {id}` and then mark the PR ready for review.

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
2. Start the lifecycle through Track:
   - run `bash .track/scripts/track-start.sh {id}`
   - this writes `status: active`, updates `updated:`, and validates before the PR opens
3. Push and open a **draft PR** immediately
   - If the branch is not `task/{id}-{slug}`, put `Track-Task: {id}` on the first line of the PR body
   - On `task/{id}-{slug}` branches, Track can resolve from the branch name, but adding `Track-Task:` is still preferred
   - Prefer PR titles like `feat(scope): [4.1] short description`
   - Use at most one `Track-Task:` line
   - Optional label: `track:{id}`
   - CI resolves the task from body, labels, title, then branch name
4. Do the implementation work with as many commits as needed
5. When ready for review:
   - run `bash .track/scripts/track-ready.sh {id}`
   - this writes `status: review`, updates `updated:`, and validates before the PR leaves draft
   - mark the PR ready for review
6. After each push, inspect mergeability if the PR matters right now:
   - `mergeStateStatus: BEHIND` means rebase or merge `origin/main` and push again
   - `mergeStateStatus: BLOCKED` with missing required checks means wait for or fix the required workflows on the latest head commit
7. When the PR merges, the post-merge workflow writes `status: done`, `pr:`, and `updated:` on `main`. If branch protections block direct writeback, it opens a follow-up writeback PR instead. Then it unblocks newly-cleared dependency tasks and regenerates Track views

Example PR linkage:

```text
Branch: any-branch-name
Title: feat(skills): [7.2] refine refresh-track skill
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

### Worktree Workflow

Track works best when each active task gets its own branch. For parallel agents, give each one its own git worktree:

```bash
git worktree add ../repo-7.4 -b task/7.4-pr-lint main
cd ../repo-7.4
```

Track assigns non-overlapping `files:` scopes to each task. Separate worktrees give each agent isolated filesystem state. Together: parallel agents, fewer conflicts, clearer PR ownership.

A single working tree is fine for serial work. The worktree pattern is recommended when running multiple agents simultaneously.

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

### Writing Specs
Save durable architecture docs, design references, and interface contracts to `.track/specs/`.
- Filename: `{slug}.md` in lowercase, hyphenated form
- Add YAML frontmatter with `title`, `status`, `created`, `updated`, and optionally `task_id`/`project_id`
- `status` should be `draft`, `approved`, or `superseded`
- Specs do not auto-expire; if a newer spec replaces one, keep the old file and mark it `superseded`

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
- **Let Track scripts drive status.** Use `bash .track/scripts/track-start.sh {id}` for draft state and `bash .track/scripts/track-ready.sh {id}` for review state. The post-merge workflow handles `status: done` automatically. Do not hand-edit in-progress status when a lifecycle script or workflow owns that transition.
- **Validate early and often.** Run `bash .track/scripts/track-validate.sh` after every task file change. Errors caught locally are cheap; errors caught in CI block the team.

### Troubleshooting

**Validation fails?** Run `bash .track/scripts/track-validate.sh` — it tells you exactly what's wrong and where to look.

**Track views are stale?** Run `bash .track/scripts/track-todo.sh` to regenerate. If you're offline: `bash .track/scripts/track-todo.sh --local --offline`

**"gh not found" or PR status missing?** Install `gh` and run `gh auth login`, then retry.

**PR says `BEHIND` or stays blocked even though old checks passed?** Fetch `origin/main`, rebase or merge it into your branch, push again, and confirm the latest head commit reruns `Track Validate`, `Track PR Lint`, and `conventional-commit-lint`. Repos with strict required checks only count the latest head commit.

**An agent is not following Track?** Re-run `/track:setup-track` to refresh the Track-managed block in `AGENTS.md`, then start a fresh agent session.

**Commands not showing up?** Re-run `~/.local/share/agent-skills/track/install.sh` to refresh the skill symlinks, then restart the agent session.
<!-- TRACK:END -->
