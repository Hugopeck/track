---
title: "Local Track Server Architecture"
status: draft
created: 2026-03-30
updated: 2026-03-30
task_id: "8.9"
project_id: "8"
---

# Local Track Server Architecture

This spec defines the architecture of the Track local runtime server — a Bun/TypeScript HTTP server that ingests activity events, attributes them to tasks, and serves a dashboard. It is the centerpiece of Track OSS.

For wire event payloads consumed by this server, see [event-contract.md](event-contract.md).

## Design Principles

- **Single binary.** `bun compile` produces one executable. No Node.js, no runtime deps on the user's machine.
- **Zero external dependencies for storage.** `bun:sqlite` is built in. No Postgres, no Redis.
- **Vendor-agnostic LLM.** Raw `fetch` against OpenAI-compatible `/v1/chat/completions`. No SDK.
- **Task files are source of truth.** `.track/tasks/*.md` is canonical. SQLite mirrors them for fast queries.
- **Untracked activity is first-class.** All events stored. Attribution is nullable, not mandatory.

## Directory Layout

```
.track/runtime/
  src/
    index.ts              — HTTP server entry point
    routes/
      events.ts           — POST /events (webhook receiver)
      tasks.ts            — GET /tasks, GET /tasks/:id
      activity.ts         — GET /activity
      health.ts           — GET /health
    db/
      schema.ts           — SQLite schema + migrations
      queries.ts          — prepared statements
    matcher/
      deterministic.ts    — branch/scope/files → task matching
      llm.ts              — OpenAI-compatible inference
      pipeline.ts         — deterministic first, LLM fallback
    sync.ts               — task file → SQLite sync
    config.ts             — configuration loading
  dashboard/
    index.html            — single-page dashboard (served on same port)
  bin/
    install.sh            — launchd/systemd service registration
  test/
    ...
  package.json
  bunfig.toml
```

## Configuration

```typescript
interface TrackConfig {
  llm: {
    base_url: string;    // e.g. "https://api.openai.com" or "http://localhost:11434/v1"
    api_key: string;
    model: string;       // e.g. "gpt-4o-mini", "claude-haiku", "llama3"
  };
  port: number;          // default: 4747
  repos: string[];       // absolute paths to watched repos
}
```

Configuration sources (highest priority first):

1. Environment variables: `TRACK_PORT`, `TRACK_LLM_BASE_URL`, `TRACK_LLM_API_KEY`, `TRACK_LLM_MODEL`
2. Config file: `~/.track/config.toml`
3. Defaults: port `4747`, no LLM (deterministic matching only)

When no LLM is configured, ambiguous events are stored as untracked. The server still functions — LLM is an enhancement, not a requirement.

## SQLite Schema

```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,          -- e.g. "4.1"
  title TEXT NOT NULL,
  status TEXT NOT NULL,         -- todo/active/review/done/cancelled
  mode TEXT,                    -- investigate/plan/implement
  priority TEXT,                -- urgent/high/medium/low
  project_id TEXT,
  files TEXT,                   -- JSON array of glob patterns
  created TEXT,                 -- ISO-8601 date
  updated TEXT,                 -- ISO-8601 date
  pr TEXT
);

CREATE TABLE events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,           -- track.commit, track.pr.opened, etc.
  timestamp TEXT NOT NULL,      -- ISO-8601
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
  date TEXT PRIMARY KEY,        -- ISO-8601 date
  total_events INTEGER,
  attributed INTEGER,
  untracked INTEGER
);

CREATE INDEX idx_events_task ON events(task_id);
CREATE INDEX idx_events_type ON events(type);
CREATE INDEX idx_events_timestamp ON events(timestamp);
```

### Migration strategy

Schema versioning uses a `schema_version` pragma stored in SQLite's `user_version`. On startup, the server checks the current version and applies migrations sequentially. Migrations are forward-only — no rollback support in v1.

## API Routes

### `POST /events`

Ingests a wire event as defined in [event-contract.md](event-contract.md).

**Request:** JSON body matching one of the six wire event schemas.

**Processing:**
1. Validate envelope fields (`type`, `version`, `timestamp`, `repo`, `branch`).
2. Run the matcher pipeline (see below).
3. Store the event with attribution result.
4. Update `activity_summary` for the event's date.

**Response:** `202 Accepted` with empty body on success. `400` on validation failure.

### `GET /tasks`

Returns all tasks from the SQLite mirror.

**Query parameters:**
- `status` — filter by status (e.g. `?status=active`)
- `project_id` — filter by project

**Response:** JSON array of task objects.

### `GET /tasks/:id`

Returns a single task with its associated events.

**Response:** Task object with an `events` array.

### `GET /activity`

Returns recent events, optionally filtered.

**Query parameters:**
- `limit` — max results (default: 50)
- `attributed` — `true` / `false` / omit for all
- `since` — ISO-8601 timestamp

**Response:** JSON array of event objects with attribution.

### `GET /health`

**Response:** `200 OK` with:
```json
{
  "status": "ok",
  "version": "1.0.0",
  "uptime_seconds": 3600,
  "repos": 2,
  "tasks": 15,
  "events_today": 23
}
```

### `GET /` (Dashboard)

Serves `dashboard/index.html`. See Dashboard section.

## Matcher Pipeline

Events flow through a two-stage attribution pipeline: deterministic matching first, LLM fallback for ambiguous cases.

```
Event arrives (POST /events)
  │
  ├─ 1. Parse event fields
  │
  ├─ 2. Deterministic matching (fast, no network):
  │   ├─ Branch match: branch contains task/{id}-* or task/{id}
  │   │   → attribute, source: matched_branch, confidence: 1.0
  │   ├─ Scope match: commit scope matches exactly one task's file globs
  │   │   → attribute, source: matched_scope, confidence: 1.0
  │   ├─ File match: changed_files overlap exactly one task's file globs
  │   │   → attribute, source: matched_scope, confidence: 1.0
  │   ├─ Multiple matches → pass to LLM
  │   └─ No match → pass to LLM
  │
  ├─ 3. LLM matching (ambiguous/unmatched only):
  │   ├─ Skip if no LLM configured → store as untracked
  │   ├─ POST {base_url}/v1/chat/completions
  │   ├─ Context: event payload + active task list with file globs
  │   ├─ Response: { task_id, confidence, reasoning }
  │   ├─ confidence > 0.8 → attribute, source: llm_inferred
  │   └─ confidence <= 0.8 → store as untracked
  │
  └─ 4. Store event + attribution result
```

### Deterministic matching rules (priority order)

1. **Branch name.** If the branch matches `task/{id}-*` or `task/{id}`, attribute to that task ID. This is the highest-confidence signal.
2. **File glob overlap.** Compare `changed_files` against each active task's `files` globs. If exactly one task matches, attribute to it.
3. **Commit scope.** If the conventional commit scope matches a single task's scope (derived from its file globs or title), attribute to it.

If multiple tasks match at steps 2 or 3, the result is `ambiguous` and falls through to LLM.

### LLM matching

```typescript
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
  const data = await response.json();
  return JSON.parse(data.choices[0].message.content);
}
```

The system prompt instructs the model to return a JSON object with `task_id` (string or null), `confidence` (0-1), and `reasoning` (short explanation). No vendor-specific features are used.

**Failure handling:** If the LLM request fails (network error, timeout, invalid response), store the event as untracked. Never block event ingestion on LLM availability.

## Task State Sync

`.track/tasks/*.md` files are the source of truth. The SQLite `tasks` table is a read-optimized mirror.

### Sync process

1. **On startup:** Scan all `.track/tasks/*.md` files across configured repos. Parse YAML frontmatter. Upsert into `tasks` table.
2. **On file change:** Use `fs.watch` on `.track/tasks/` directories. Re-parse and upsert changed files.
3. **Periodic fallback:** Re-sync every 60 seconds to catch changes missed by file watchers.

### Effective status computation

The server computes effective status using the same rules as the Track protocol:

- Raw `done` or `cancelled` → effective status matches raw
- Open draft PR linked to task → effective `active`
- Open ready-for-review PR linked to task → effective `review`
- Otherwise → effective status matches raw

PR linkage is resolved by checking `Track-Task: {id}` in PR body, `track:{id}` labels, task ID in title, or `task/{id}-*` branch name. The server caches PR state and refreshes it via `gh` CLI or GitHub API periodically.

## LLM Integration Details

### Provider compatibility

The server targets any provider exposing the OpenAI-compatible chat completions API:

| Provider | `base_url` | Notes |
|----------|-----------|-------|
| OpenAI | `https://api.openai.com` | Direct |
| Anthropic | Via OpenAI-compatible proxy | e.g. LiteLLM |
| Ollama | `http://localhost:11434/v1` | Local models |
| Any OpenAI-compatible | Custom URL | Azure, Together, etc. |

### No SDK dependency

All LLM communication uses raw `fetch`. No `openai`, `anthropic`, or other SDK packages. This keeps the binary small and avoids version coupling.

### Attribution prompt design

The system prompt for LLM attribution:

1. Presents the list of active tasks with their IDs, titles, file globs, and current status.
2. Presents the event to attribute (commit message, changed files, branch, scope).
3. Asks the model to return `{ task_id, confidence, reasoning }` as JSON.
4. Instructs the model to return `task_id: null` when no task is a good match.

The prompt is self-contained — no conversation history, no tool use. Each attribution is a single request/response.

## Dashboard

A single-page HTML file served by the same HTTP server on the configured port (default `localhost:4747`).

### Wireframe

```
┌─────────────────────────────────────────┐
│  Track Dashboard                   ⟳    │
│                                         │
│  TASKS                                  │
│  ● 4.1 Auth flow           active       │
│  ● 4.2 Rate limiter        review       │
│  ○ 4.3 Logging             todo         │
│  ✓ 4.4 Error handling      done         │
│                                         │
│  RECENT ACTIVITY                        │
│  feat(auth): add JWT        → 4.1   2h  │
│  fix(api): handle timeout     ○     5h  │
│  refactor(utils): cleanup     ○     1d  │
│                                         │
│  ─────────────────────────────────────  │
│  This week: 23 commits                  │
│  ├── 15 task-attributed                 │
│  └── 8 untracked                        │
└─────────────────────────────────────────┘
```

### Behavior

- `●` = task has activity, `○` = untracked event or idle task, `✓` = done
- Clicking an untracked event (`○`) offers retroactive attribution via `track.link`
- Task list fetched from `GET /tasks`, activity from `GET /activity`
- Auto-refreshes every 30 seconds
- No build step — vanilla HTML/CSS/JS, no framework
- Responsive: usable on mobile for quick status checks

## Install Flow

### Binary distribution

`bun compile` produces a single executable:

```bash
bun build --compile src/index.ts --outfile track-server
```

The binary is distributed to `~/.track/bin/track-server`.

### Service registration

#### macOS (launchd)

The install script generates and loads a launchd plist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.track.server</string>
  <key>ProgramArguments</key>
  <array>
    <string>~/.track/bin/track-server</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>~/.track/logs/server.log</string>
  <key>StandardErrorPath</key>
  <string>~/.track/logs/server.err</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>TRACK_PORT</key>
    <string>4747</string>
  </dict>
</dict>
</plist>
```

Install:
```bash
cp com.track.server.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.track.server.plist
```

Uninstall:
```bash
launchctl unload ~/Library/LaunchAgents/com.track.server.plist
rm ~/Library/LaunchAgents/com.track.server.plist
```

#### Linux (systemd)

The install script generates and enables a systemd user service:

```ini
[Unit]
Description=Track local server
After=network.target

[Service]
Type=simple
ExecStart=%h/.track/bin/track-server
Restart=on-failure
RestartSec=5
Environment=TRACK_PORT=4747
StandardOutput=append:%h/.track/logs/server.log
StandardError=append:%h/.track/logs/server.err

[Install]
WantedBy=default.target
```

Install:
```bash
mkdir -p ~/.config/systemd/user/
cp track-server.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now track-server
```

Uninstall:
```bash
systemctl --user disable --now track-server
rm ~/.config/systemd/user/track-server.service
systemctl --user daemon-reload
```

### Install script (`bin/install.sh`)

The install script handles both platforms:

```
1. Detect OS (uname -s)
2. Copy binary to ~/.track/bin/track-server
3. Create ~/.track/logs/ directory
4. Initialize SQLite database (track-server init)
5. Generate service file for detected platform
6. Register and start service
7. Health check: curl localhost:4747/health
8. Report success or failure
```

The script is idempotent — running it again updates the binary and restarts the service without losing data.

## Downstream References

- [event-contract.md](event-contract.md) — wire event payloads consumed by `POST /events`
- Task 8.3 — hook emitters that produce events for this server
- Task 8.5 — unified skill emitting `track.task.started` and `track.link`
- `.track/plans/track-oss-alignment.md` Part 2 — original design context
