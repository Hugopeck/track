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
- `skills/` — installable agent skills (each subdirectory is a standalone skill)
- `skills/init/assets/` — everything the init skill deploys to adopting repos (scripts, workflows, config)
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
| `init` | Deploy `.track/`, scripts, workflows, and Track sections into a new repo |
| `create` | Create tasks and projects |
| `decompose` | Break a goal into tasks with dependencies |
| `validate` | Run validation and interpret errors |
| `todo` | Regenerate `BOARD.md`, `TODO.md`, and `PROJECTS.md` |
| `test` | Run the test suite |
| `update-track` | Self-update Track skills to latest version |

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

Common scopes: `skills`, `scripts`, `init`, `work`, `create`, `decompose`, `validate`, `todo`

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

Track is a git-native coordination system. It is the source of truth for task state, task ownership, and task history. Follow its conventions and it keeps everything organized. The protocol below is both reference and guide.

Projects, tasks, plans, and specs live in `.track/`. `TODO.md` is the generated shared view of current work.

### Layout
- `.track/projects/{project_id}-{slug}.md` — project briefs
- `.track/tasks/{task_id}-{slug}.md` — flat task files
- `.track/plans/{slug}.md` — short-lived plan documents (auto-expire after 7 days)
- `.track/specs/{slug}.md` — durable architecture, design, and interface specs
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
- **Let the system track status.** Don't manually update status fields to show progress. Open a draft PR — Track knows you're active. Mark it ready for review — Track knows you're in review. The PR lifecycle is the status lifecycle.
- **Validate early and often.** Run `bash .track/scripts/track-validate.sh` after every task file change. Errors caught locally are cheap; errors caught in CI block the team.
<!-- TRACK:END -->
