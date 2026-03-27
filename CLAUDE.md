# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context

This is the Track plugin repo. Track is a git-native task coordination system distributed as a Claude Code plugin. No build step, no runtime — the plugin is markdown skills and bash scripts.

## Commands

```bash
# Run all tests
bash tests/test-validate.sh && bash tests/test-validate-extended.sh && bash tests/test-todo.sh && bash tests/test-todo-extended.sh && bash tests/test-pr-lint.sh && bash tests/test-complete.sh

# Run a single test
bash tests/test-validate.sh

# Validate .track/ state
bash .track/scripts/track-validate.sh

# Regenerate TODO.md
bash .track/scripts/track-todo.sh              # default: origin/main + live PR data
bash .track/scripts/track-todo.sh --local      # local working tree
bash .track/scripts/track-todo.sh --offline    # skip GitHub PR lookup

# Test plugin locally
claude --plugin-dir .
```

After editing skills, run `/reload-plugins` to pick up changes.

## Architecture

The plugin has two layers:

1. **Skills** (`skills/`) — markdown protocols that teach Claude the Track workflow. Each skill has a `SKILL.md` with YAML frontmatter (name, description, allowed-tools) and instructional content.
2. **Scripts** (`.track/scripts/`) — bash enforcement scripts that validate task files, generate TODO.md, lint PRs, and handle post-merge completion. Scripts live inside `.track/` by design.

### Dual-Copy Scripts

Scripts exist in two identical locations:
- `.track/scripts/` — used by this repo's own `.track/` (Track dogfoods itself)
- `skills/init/scaffold/track/scripts/` — copied into adopting repos by `/track:init`

Changes to scripts must be mirrored in both locations. The scaffold copies are the canonical source that gets distributed.

### Key Files

- `.claude-plugin/plugin.json` — plugin manifest (name, version, description)
- `skills/init/scaffold/` — everything copied into adopting repos by `/track:init`
- `skills/init/scaffold/CLAUDE_TRACK_SECTION.md` — the CLAUDE.md section appended to adopting repos
- `skills/work/SKILL.md` — the core workflow protocol (auto-loaded when `.track/` exists)
- `.track/scripts/track-common.sh` — shared YAML frontmatter parser and utility functions used by all scripts

### Skill Inventory

| Skill | Purpose |
|-------|---------|
| `init` | Scaffold `.track/`, scripts, workflows, and CLAUDE.md section into a new repo |
| `work` | Core workflow protocol — reading state, picking work, PR lifecycle |
| `create` | Create tasks and projects |
| `decompose` | Break a goal into tasks with dependencies |
| `validate` | Run validation and interpret errors |
| `todo` | Regenerate TODO.md |

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

- Version lives in `.claude-plugin/plugin.json` — do not edit manually
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

- Adopting repos are self-contained — they never depend on this plugin at runtime
- The plugin teaches Claude the Track protocol; the scripts enforce it
- bash 3.2+ compatibility required (macOS default)

## Track — Task Coordination

This repo uses Track to manage its own work. Projects and tasks live in `.track/`.

### Agent protocol (primary)

1. Read `TODO.md` for current state. Pick a `todo` task or resume an `active` one.
2. Check file scopes — do not touch files owned by another in-progress task.
3. Open a **draft PR** to start work. No PR = not started.
4. Implement. When ready, mark the PR ready for review.
5. If `gh` auth fails or PR creation fails, **stop and surface the error.**

`TODO.md` is generated — edit task files in `.track/tasks/`, not TODO.md directly.

### Fallback

`/track:work` contains the full protocol with edge cases. Use it when this section is insufficient.
