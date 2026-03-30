---
title: "Track-OSS Alignment Plan"
created: 2026-03-30
project_id: "8"
---

# Track-OSS Alignment Plan

## Context

Track is being reshaped into two products:
- **Track OSS** — Full-featured local server with LLM inference. Free, open source, user's API key, Bun/TS binary.
- **Track Cloud** — Managed hosted server for teams. Revenue layer.

This repo becomes the protocol, skills, and script foundation. A separate `track-server` repo holds the Bun server. Both repos are scoped here because they share the event contract.

Key shifts from current state:
- **9 skills → 2**: unified `track` (auto-discovered) + `init`
- **Server-side detection** replaces agent-side enforcement for lifecycle
- **LLM-vendor-agnostic**: OpenAI-compatible API (`/v1/chat/completions`), any provider
- **Untracked activity** is first-class: all git events logged, attribution is nullable
- **Bun/TypeScript** server: `bun compile` for binary, `bun:sqlite` built-in, largest contributor pool
- **GitHub Rulesets** deployed by init to enforce CI checks

---

## Part 1: This Repo (track — skills, protocol, hooks)

### 1A. Skill Consolidation (9 → 2)

**Merge into unified `track` skill** (auto-discovered in `.track/` repos):

| User intent | Current skill | New: handled by unified `track` |
|-------------|--------------|--------------------------------|
| "What should I work on?" | work (pick mode) | Read state, pick task |
| "Start task 4.1" | work (resume mode) | Create branch, open draft PR, emit event |
| "Create a task for X" | create | Create task file, validate, regenerate |
| "Break this into tasks" | decompose | Explore codebase, propose breakdown, create files |
| "Link this to task 4.1" | (new) | Emit `track.link` event for retroactive attribution |
| "Add context: found that..." | work (mid-task) | Append to task Notes section |
| "What's the status?" | todo | Query server API or regenerate views |

**Skills to remove as standalone:**
- `validate` → becomes a script only (already is). Runs in hooks + CI, not invoked by user.
- `todo` → server dashboard replaces this. Script remains as offline fallback.
- `test` → internal dev tool for this repo only. Not shipped to adopters.
- `update-track` → becomes a script or server feature.
- `runtime` → stays as shared bash library (not a skill).

**Result:** `skills/track/SKILL.md` + `skills/init/SKILL.md`. Two entry points.

**File changes:**
- Create `skills/track/SKILL.md` — unified skill with mode detection from user intent
- Retire `skills/work/`, `skills/create/`, `skills/decompose/` as standalone skills (content merges into unified skill)
- Keep `skills/validate/scripts/`, `skills/todo/scripts/` as scripts (not skills)
- Keep `skills/runtime/scripts/track-common.sh` as shared library
- Update `skills/init/SKILL.md` for hooks + rulesets

### 1B. Event Contract — `EVENT-CONTRACT.md`

The interface between this repo and track-server. Lives at repo root.

**Event types:**
```
track.commit        — post-commit hook fires
track.pr.opened     — draft PR opened
track.pr.ready      — PR marked ready for review
track.pr.merged     — PR merged
track.task.started  — via /track start or first commit on task branch
track.link          — retroactive attribution (/track link {id})
```

**Payload schema:**
```json
{
  "type": "track.commit",
  "version": "1",
  "timestamp": "ISO-8601",
  "repo": "owner/repo",
  "branch": "task/4.1-feature",
  "commit_sha": "abc123",
  "changed_files": ["src/api/auth.ts", "tests/auth.test.ts"],
  "conventional_commit": {
    "type": "feat",
    "scope": "auth",
    "subject": "add rate limiting",
    "breaking": false
  }
}
```

**Attribution model** (server applies, documented here):
- `task_id`: nullable — `null` = untracked activity
- `attribution`: `matched_branch` / `matched_scope` / `llm_inferred` / `manual` / `null`
- ALL events stored regardless of attribution

**LLM interface spec:**
- OpenAI-compatible: `POST {base_url}/v1/chat/completions`
- Config: `base_url` + `api_key` + `model`
- No vendor-specific code anywhere. Works with Anthropic (via proxy), OpenAI, Ollama, etc.

### 1C. Hook Templates

**`skills/init/assets/hooks/commit-msg`** — bash-only conventional commit linter
- Regex: `^(feat|fix|docs|refactor|test|ci|chore)(\(.+\))?!?: .+`
- Pure bash 3.2+, zero deps
- Clear error with expected format on rejection

**`skills/init/assets/hooks/post-commit`** — event emitter
- Extracts changed files, parses conventional commit fields
- Runs deterministic scope matching (`track_match_files_to_task()`)
- POSTs to `localhost:${TRACK_PORT:-4747}/events` if server responds
- Falls back to `.track/events/log.jsonl` (gitignored) — never blocks commit

### 1D. Scope Matching in track-common.sh

Add `track_match_files_to_task()`:
- Input: list of changed file paths
- Output: matched task ID(s) + confidence (`deterministic` / `ambiguous` / `unmatched`)
- Reuses existing glob approach from `track_globs_overlap_serialized`
- Pre-LLM filter: deterministic matches skip inference; ambiguous goes to server's LLM

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

### 1F. Documentation Updates

- **TRACK.md** — two-product model, event contract reference, untracked activity concept
- **README.md** — position as Track OSS (full product, not demo), vendor-agnostic LLM
- **AGENTS.md** — unified skill reference, hook-aware instructions
- **skills-guide.md** — rewrite for 2-skill model

### 1G. Tests

- `tests/test-scope-matching.sh` — deterministic matcher
- `tests/test-commit-lint.sh` — bash linter accept/reject
- `tests/test-event-contract.sh` — hook JSON output format
- `tests/test-ruleset.sh` — validate ruleset JSON structure
- Update existing tests for skill consolidation

---

## Part 2: Server Repo (track-server — Bun/TS)

### 2A. Why Bun

- `bun compile` → single binary, no runtime needed on user's machine
- `bun:sqlite` → built-in, zero deps
- Built-in HTTP server (fast, simple)
- TypeScript → largest contributor pool for OSS
- Development velocity: fastest iteration for a server this simple

### 2B. Server Architecture

```
track-server/
  src/
    index.ts              — HTTP server entry point
    routes/
      events.ts           — POST /events (webhook receiver)
      tasks.ts            — GET /tasks, GET /tasks/:id
      activity.ts         — GET /activity (untracked stream)
      health.ts           — GET /health
    db/
      schema.ts           — SQLite schema + migrations
      queries.ts          — prepared statements
    matcher/
      deterministic.ts    — branch/scope → task matching
      llm.ts              — OpenAI-compatible inference for ambiguous cases
      pipeline.ts         — deterministic first, LLM fallback
    config.ts             — base_url, api_key, model, port
  dashboard/
    index.html            — single-page dashboard (served by same port)
  bin/
    install.sh            — launchd/systemd registration
  test/
    ...
  package.json
  bunfig.toml
```

### 2C. SQLite Schema

```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,          -- "4.1"
  title TEXT NOT NULL,
  status TEXT NOT NULL,         -- todo/active/review/done/cancelled
  mode TEXT,
  priority TEXT,
  project_id TEXT,
  files TEXT,                   -- JSON array of globs
  created TEXT,
  updated TEXT,
  pr TEXT
);

CREATE TABLE events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,           -- track.commit, track.pr.opened, etc.
  timestamp TEXT NOT NULL,
  repo TEXT,
  branch TEXT,
  commit_sha TEXT,
  commit_type TEXT,             -- feat/fix/refactor/...
  commit_scope TEXT,
  commit_subject TEXT,
  changed_files TEXT,           -- JSON array
  task_id TEXT,                 -- nullable: null = untracked
  attribution TEXT,             -- matched_branch/matched_scope/llm_inferred/manual/null
  raw_payload TEXT              -- full event JSON for debugging
);

CREATE TABLE activity_summary (
  date TEXT PRIMARY KEY,
  total_events INTEGER,
  attributed INTEGER,
  untracked INTEGER
);
```

### 2D. Event Processing Pipeline

```
Event arrives (POST /events)
  │
  ├─ Parse conventional commit fields
  │
  ├─ Deterministic matching:
  │   ├─ Branch matches task/{id}-* ? → attribute, confidence: matched_branch
  │   ├─ Commit scope matches single task's scope? → attribute, confidence: matched_scope
  │   ├─ Multiple matches? → pass to LLM
  │   └─ No match? → pass to LLM
  │
  ├─ LLM matching (ambiguous/unmatched only):
  │   ├─ POST {base_url}/v1/chat/completions
  │   ├─ Context: commit info + active task list
  │   ├─ Response: task_id or "untracked" + reasoning
  │   ├─ Confidence threshold: only attribute if confidence > 0.8
  │   └─ Below threshold → store as untracked
  │
  └─ Store event with attribution (or null)
```

### 2E. Task State Sync

The server reads `.track/tasks/*.md` files as the source of truth for task definitions. SQLite mirrors them for fast queries. On startup and periodically:
1. Scan `.track/tasks/` for all task files
2. Parse YAML frontmatter
3. Upsert into `tasks` table
4. Effective status computed from: raw status + open PRs (via `gh` CLI or cached)

### 2F. LLM Integration (Vendor-Agnostic)

```typescript
// config.ts
interface TrackConfig {
  llm: {
    base_url: string;    // "https://api.openai.com" or "http://localhost:11434/v1"
    api_key: string;
    model: string;       // "gpt-4o-mini" or "claude-haiku" or "llama3"
  };
  port: number;          // default 4747
  repos: string[];       // paths to watched repos
}
```

```typescript
// llm.ts — uses fetch, no SDK dependency
async function inferTaskAttribution(
  event: TrackEvent,
  activeTasks: Task[]
): Promise<{ task_id: string | null; confidence: number; reasoning: string }> {
  const response = await fetch(`${config.llm.base_url}/v1/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${config.llm.api_key}`
    },
    body: JSON.stringify({
      model: config.llm.model,
      messages: [
        { role: "system", content: ATTRIBUTION_PROMPT },
        { role: "user", content: formatEventContext(event, activeTasks) }
      ],
      response_format: { type: "json_object" }
    })
  });
  // ...
}
```

No Anthropic SDK, no OpenAI SDK. Raw `fetch` against the OpenAI-compatible API standard. Works with any provider.

### 2G. Install Flow

```
User: "Set up Track for this project"

Agent (via /track:init skill):
1. Download track-server binary → ~/.track/track-server
2. Initialize: track-server init (creates SQLite DB + default config)
3. Check for LLM API key:
   - Env: OPENAI_API_KEY, ANTHROPIC_API_KEY, or TRACK_LLM_API_KEY
   - Found → configure in ~/.track/config.toml
   - Not found → prompt user, explain why it's needed
4. Register as background service:
   - macOS: launchd plist (~/.track/com.track.server.plist)
   - Linux: systemd user service
5. Install git hooks in repo (.git/hooks/ or .husky/)
6. Deploy GitHub Actions workflows
7. Deploy GitHub Ruleset (if admin access)
8. Create .track/ directory structure
9. Verify: health check + test inference call
```

### 2H. Dashboard

Simple single-page HTML served on `localhost:4747`:

```
┌─────────────────────────────────────┐
│  Track Dashboard                    │
│                                     │
│  TASKS                              │
│  ● 4.1 Auth flow        active      │
│  ● 4.2 Rate limiter     review      │
│  ○ 4.3 Logging          todo        │
│                                     │
│  RECENT ACTIVITY                    │
│  feat(auth): add JWT     → 4.1  2h  │
│  fix(api): handle timeout  ○    5h  │
│  refactor(utils): cleanup  ○    1d  │
│                                     │
│  This week: 23 commits              │
│  ├── 15 task-attributed             │
│  └── 8 untracked                    │
└─────────────────────────────────────┘
```

`○` = untracked. Clicking it offers retroactive attribution.

---

## Implementation Phases

### Phase 1: Foundation (this repo)
1. Write `EVENT-CONTRACT.md`
2. Add `track_match_files_to_task()` to track-common.sh
3. Create hook templates (commit-msg linter + post-commit emitter)
4. Create `track-ruleset.json`
5. Tests for all of the above

### Phase 2: Skill Consolidation (this repo)
1. Create unified `skills/track/SKILL.md`
2. Update `skills/init/SKILL.md` (hooks + rulesets)
3. Retire standalone skills (work, create, decompose, validate, todo, test, update-track)
4. Update all documentation (TRACK.md, README.md, AGENTS.md)

### Phase 3: Server Bootstrap (track-server repo)
1. Scaffold Bun project with SQLite schema
2. Event ingestion endpoint (`POST /events`)
3. Deterministic matcher (branch/scope → task)
4. Task sync from `.track/tasks/` files
5. REST API for queries
6. Health check endpoint

### Phase 4: LLM Integration (track-server repo)
1. OpenAI-compatible inference module
2. Attribution pipeline (deterministic → LLM fallback)
3. Confidence thresholding
4. Prompt tuning

### Phase 5: Install Experience (both repos)
1. `bun compile` binary distribution
2. launchd/systemd service registration
3. Init skill wires everything together
4. End-to-end verification

### Phase 6: Dashboard (track-server repo)
1. Single-page HTML dashboard
2. Task view + untracked activity stream
3. Retroactive attribution UI
4. Attribution ratio metrics

---

## Resolved Decisions

1. **Two products**: Track OSS (full local + LLM) and Track Cloud (managed). No crippled tier.
2. **Server language**: Bun/TypeScript. `bun compile` for binary, `bun:sqlite` built-in, largest ecosystem.
3. **2 skills**: Unified `track` (auto-discovered) + `init`. Everything else is scripts or server features.
4. **LLM-vendor-agnostic**: OpenAI-compatible API via raw `fetch`. `base_url` + `api_key` + `model`. No SDK deps.
5. **Untracked activity**: First-class. All events logged, attribution nullable. `/track link` for retroactive.
6. **GitHub Rulesets**: Deployed by init to enforce Track CI checks.
7. **No Node.js dependency**: Bash-only commit linter in hooks. Zero external deps.
8. **Event log fallback**: `.track/events/log.jsonl` (gitignored) when no server.
9. **Existing tasks**: New project for alignment work; existing projects untouched.
10. **Scope**: Strategic plan + server architecture. Implementation via decomposed tasks.

## Verification

- `bash tests/run-all.sh` passes (no regressions)
- `bash .track/scripts/track-validate.sh` passes
- New tests pass (scope matching, commit lint, event contract, ruleset)
- Unified skill handles all current skill use cases
- Hook templates produce valid JSON per EVENT-CONTRACT.md
- Server (when built) ingests events and returns correct attributions
- `bun compile` produces working binary
- Install flow works end-to-end on macOS (launchd) and Linux (systemd)
