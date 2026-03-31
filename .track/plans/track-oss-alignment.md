---
title: "Track-OSS Alignment Plan"
created: 2026-03-30
updated: 2026-03-31
project_id: "8"
---

# Track-OSS Alignment Plan

## Context

Track is a git-native coordination protocol: markdown skills, bash scripts, git hooks, and GitHub workflows. No binary, no server, no runtime.

This repo is the protocol, skills, and scripts. Cloud (managed hosting for teams) is a separate future project with its own requirements.

Key shifts from current state:
- **Skill refinement**: extend `work` with link/context modes, no dispatcher, keep `work`/`create`/`decompose` standalone
- **Untracked activity** is first-class: all git events logged to JSONL, attribution is nullable
- **GitHub workflows** are the automation layer: cascade unblocks, PR lifecycle sync
- **GitHub Rulesets** deployed by init to enforce CI checks
- **No server/runtime**: deterministic matching in bash, JSONL logging, editor-native views

### Why no server

The server's unique value was real-time LLM attribution (~20% of ambiguous commits). Everything else — event logging, task state, views — is already handled by bash scripts and JSONL files. Additional reasons:

- **Dashboard loses to editor views.** TODO.md and BOARD.md render in the editor, avoiding context switching.
- **Cloud needs a different server.** Multi-repo, teams, auth, billing — fundamentally different from a local single-binary. Building now creates premature coupling.
- **Zero infrastructure is a feature.** Track adopters drop files into a repo. No binary to install, no process to manage, no port conflicts.

The server architecture spec (produced by task 8.9) is retained as `superseded` reference for Cloud.

---

## Part 1: This Repo (track — skills, protocol, hooks)

### 1A. Skill Refinement

**Extend `skills/work/SKILL.md`** with two new sub-modes:

| User intent | Mode |
|-------------|------|
| "Link this to task 4.1" | link — emit `track.link` event to JSONL for retroactive attribution |
| "Add context: found that..." | context — append to task Notes section |

**Skills that stay standalone:**
- `create` — distinct workflow, separate context
- `decompose` — distinct workflow, separate context
- `refresh-track` — retained as a user-invocable skill for regenerating views.
- `update-skills` — retained as an auto-loaded updater skill for refreshing installed Track skills.

**Skills retired as installable skills:**
- `validate` → script only. Runs in hooks + CI.
- `test` → script only for this repo's internal development.
- `runtime` → stays as shared bash library (not a skill).

### 1B. Event Contract — `.track/specs/event-contract.md`

The wire event format for Track's JSONL activity log. Lives in `.track/specs/`.

**Event types:**
```
track.commit        — post-commit hook fires
track.pr.opened     — draft PR opened
track.pr.ready      — PR marked ready for review
track.pr.merged     — PR merged
track.task.started  — via /track start or first commit on task branch
track.link          — retroactive attribution (/track link {id})
```

**Attribution model** (deterministic matching in bash):
- `task_id`: nullable — `null` = untracked activity
- `attribution_source`: `matched_branch` / `matched_scope` / `manual` / `null`
- ALL events stored regardless of attribution
- Future: batch `track-attribute.sh` script for LLM-based resolution of ambiguous entries

### 1C. Hook Templates

**`skills/init/assets/hooks/commit-msg`** — bash-only conventional commit linter
- Regex: `^(feat|fix|docs|refactor|test|ci|chore)(\(.+\))?!?: .+`
- Pure bash 3.2+, zero deps
- Clear error with expected format on rejection

**`skills/init/assets/hooks/post-commit`** — event emitter
- Extracts changed files, parses conventional commit fields
- Writes JSON event to `.track/events/log.jsonl` (gitignored)
- Never blocks the commit

### 1D. Scope Matching in track-common.sh

Add `track_match_files_to_task()`:
- Input: list of changed file paths
- Output: matched task ID(s) + confidence (`deterministic` / `ambiguous` / `unmatched`)
- Reuses existing glob approach from `track_globs_overlap_serialized`

### 1E. Init Skill: Hooks + Rulesets

**Hook deployment** (new phase in init):
- Deploy `commit-msg` and `post-commit` to `.git/hooks/`
- Detect `.husky/` — if present, deploy there instead
- Make executable

**GitHub Ruleset deployment** (new phase in init):
- Deploy `skills/init/assets/track-ruleset.json`
- Ruleset enforces: `track-validate`, `track-pr-lint`, `conventional-commit-lint` checks
- Requires linear history, dismiss stale reviews
- Applied via `gh api -X POST /repos/:owner/:repo/rulesets --input ruleset.json`
- Gated on: repo admin access (skip with message if not available)

**`skills/init/assets/track-ruleset.json`:**
```json
{
  "name": "Track Protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main", "refs/heads/master"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true
    }},
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "track-validate" },
          { "context": "track-pr-lint" }
        ]
    }}
  ]
}
```

### 1F. Reactivity via GitHub Workflows

GitHub workflows replace what a server would have done reactively:

| Trigger | What it does |
|---|---|
| PR merge | Mark task done, cascade unblocks, regenerate views |
| PR opened as draft | Validate `Track-Task` linkage |
| PR ready for review | (future) Set task `review` |
| PR closed without merge | (future) Reset task to `todo` |
| Schedule (daily) | (future) Run validation, flag stale `active` tasks |

**Cascade unblocks** (added to post-merge workflow):
1. PR merges → workflow fires
2. Mark linked task `done`
3. Scan all `todo`/`blocked` tasks for `depends_on` containing the completed task ID
4. If ALL dependencies are now `done` → remove the block
5. Regenerate TODO.md/BOARD.md, commit

### 1G. Documentation Updates

- **TRACK.md** — pure protocol model, event contract reference, untracked activity concept
- **README.md** — position as git-native task coordination with zero infrastructure
- **AGENTS.md** — skill reference, hook-aware instructions
- **skills-guide.md** — updated for current skill set

### 1H. Tests

- `tests/test-scope-matching.sh` — deterministic matcher
- `tests/test-commit-lint.sh` — bash linter accept/reject
- `tests/test-event-contract.sh` — hook JSON output format
- `tests/test-ruleset.sh` — validate ruleset JSON structure
- Update existing tests for skill changes

---

## Implementation Phases

### Phase 1: Foundation (this repo)
1. Write `.track/specs/event-contract.md`
2. Add `track_match_files_to_task()` to track-common.sh
3. Create hook templates (commit-msg linter + post-commit emitter)
4. Create `track-ruleset.json`
5. Tests for all of the above

### Phase 2: Skill Refinement + Automation (this repo)
1. Add link/context modes to `skills/work/SKILL.md`
2. Update `skills/init/SKILL.md` (hooks + rulesets)
3. Retire script-only skills and rename retained utility skills
4. Add cascade unblocks to post-merge workflow
5. Update all documentation (TRACK.md, README.md, AGENTS.md)

---

## Resolved Decisions

1. **No server/runtime.** Track is skills + scripts + hooks + workflows. No binary, no SQLite, no HTTP server, no dashboard. Server architecture spec retained as `superseded` reference for Cloud.
2. **Skill refinement, not monolith merge.** Extend work with link/context modes. No thin dispatcher — skill framework handles routing natively. work/create/decompose remain as standalone skills.
3. **Untracked activity**: First-class. All events logged to JSONL, attribution nullable. `/track link` for retroactive.
4. **JSONL is the activity log, not the database.** Task files remain source of truth. JSONL records git history. They stay separate.
5. **GitHub workflows are the automation layer.** Cascade unblocks, PR lifecycle sync, validation — all via workflow triggers.
6. **GitHub Rulesets**: Deployed by init to enforce Track CI checks.
7. **No Node.js dependency**: Bash-only commit linter in hooks. Zero external deps.
8. **Existing tasks**: New project for alignment work; existing projects untouched.
9. **Deterministic matching is good enough.** Branch naming, commit message IDs, and `files:` glob overlap cover ~80% of attribution. Batch LLM attribution is a future follow-up.

## Caveats

- **Cross-repo coordination requires Cloud.** If task A in repo X unblocks task B in repo Y, local bash can't handle it.
- **JSONL doesn't scale to millions of events.** Fine for single-repo projects; problematic at very high commit volume.
- **Bash YAML parsing is fragile.** `track-common.sh` parses frontmatter with sed/awk. Known limitation.
- **No LLM calls from bash.** Batch attribution script would need Python or Node. Separate deliverable.
- **macOS bash 3.2 constraints remain.** No associative arrays, no `readarray`.

## Verification

- `bash tests/run-all.sh` passes (no regressions)
- `bash .track/scripts/track-validate.sh` passes
- New tests pass (scope matching, commit lint, event contract, ruleset)
- Hook templates produce valid JSON per `.track/specs/event-contract.md`
- Work skill handles link and context modes
- Init skill deploys hooks + rulesets
