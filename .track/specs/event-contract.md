# Event Contract

This document defines the event contract used by Track components in this repository. Emitters produce wire events to the JSONL activity log. Future consumers (batch scripts, Cloud) may enrich them with attribution.

## Scope

This spec defines the v1 event interface between Track's local emitters and the JSONL activity log. Future consumers (batch attribution scripts, Cloud services) may also read this format.

### In scope

- Wire event payloads emitted by hooks, skills, and scripts
- Shared envelope fields across all event types
- Attribution result model for enriched events
- Versioning and compatibility rules for future extensions

### Non-goals

- Hook implementation details
- Server or runtime implementation details
- Executable event contract tests

## Contract Role

Use this document as the canonical contract between:

- Git hooks that emit activity
- Skills and scripts that emit lifecycle events
- Batch attribution scripts and future Cloud services that consume the log

This is an internal interface for this repository. It is not a cross-repository boundary.

## Storage Contract

- Format: JSONL (one JSON object per line)
- Location: `.track/events/log.jsonl` (gitignored)
- Append-only: emitters append; consumers read
- Each line matches one of the six wire-event schemas in this document

## Common Wire Event Envelope

All v1 wire events share the same required top-level fields:

- `type` — one of the six event names defined below
- `version` — string constant `"1"`
- `timestamp` — RFC 3339 / ISO-8601 timestamp string
- `repo` — non-empty repository identifier string
- `branch` — non-empty branch name string

### Envelope semantics

- `repo` identifies the current repository only
- Preferred `repo` value is `owner/repo` when it can be resolved from Git remote metadata
- If remote metadata is unavailable, a stable local repository identifier is acceptable
- `branch` is the active branch at emit time
- Wire events are append-only facts and do not represent final attribution state unless the event itself is inherently task-specific

### Base schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "track.event.base.v1",
  "type": "object",
  "properties": {
    "type": {
      "type": "string",
      "enum": [
        "track.commit",
        "track.pr.opened",
        "track.pr.ready",
        "track.pr.merged",
        "track.task.started",
        "track.link"
      ]
    },
    "version": {
      "type": "string",
      "const": "1"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time"
    },
    "repo": {
      "type": "string",
      "minLength": 1
    },
    "branch": {
      "type": "string",
      "minLength": 1
    }
  },
  "required": ["type", "version", "timestamp", "repo", "branch"]
}
```

## Event Types

| Event type | Producer | Purpose |
| --- | --- | --- |
| `track.commit` | post-commit hook | Record a commit and its changed files |
| `track.pr.opened` | PR lifecycle integration | Record that a draft PR was opened |
| `track.pr.ready` | PR lifecycle integration | Record that a PR left draft state |
| `track.pr.merged` | PR lifecycle integration | Record that a PR merged |
| `track.task.started` | unified `track` flow or lifecycle integration | Record that task work became active |
| `track.link` | unified `track` flow | Record manual retroactive attribution |

## `track.commit`

Purpose: record a repository commit with enough context for deterministic attribution.

### Example

```json
{
  "type": "track.commit",
  "version": "1",
  "timestamp": "2026-03-30T09:15:00Z",
  "repo": "Hugopeck/track",
  "branch": "task/8.1-event-contract",
  "commit_sha": "abc123def456",
  "changed_files": [
    ".track/specs/event-contract.md",
    ".track/tasks/8.1-event-contract.md"
  ],
  "conventional_commit": {
    "type": "docs",
    "scope": "specs",
    "subject": "define event contract",
    "breaking": false
  }
}
```

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "track.event.commit.v1",
  "type": "object",
  "properties": {
    "type": { "const": "track.commit" },
    "version": { "type": "string", "const": "1" },
    "timestamp": { "type": "string", "format": "date-time" },
    "repo": { "type": "string", "minLength": 1 },
    "branch": { "type": "string", "minLength": 1 },
    "commit_sha": { "type": "string", "minLength": 1 },
    "changed_files": {
      "type": "array",
      "items": { "type": "string", "minLength": 1 },
      "minItems": 1
    },
    "conventional_commit": {
      "type": "object",
      "properties": {
        "type": {
          "type": "string",
          "enum": ["feat", "fix", "docs", "refactor", "test", "ci", "chore"]
        },
        "scope": {
          "type": ["string", "null"],
          "minLength": 1
        },
        "subject": {
          "type": "string",
          "minLength": 1
        },
        "breaking": {
          "type": "boolean"
        }
      },
      "required": ["type", "scope", "subject", "breaking"]
    }
  },
  "required": [
    "type",
    "version",
    "timestamp",
    "repo",
    "branch",
    "commit_sha",
    "changed_files",
    "conventional_commit"
  ]
}
```

Semantics: this event is emitted by the post-commit hook. `scope` is nullable because conventional commits may omit a scope. Final `task_id` attribution is not required on ingress.

## `track.pr.opened`

Purpose: record that a draft PR was opened for a primary task.

### Example

```json
{
  "type": "track.pr.opened",
  "version": "1",
  "timestamp": "2026-03-30T09:20:00Z",
  "repo": "Hugopeck/track",
  "branch": "task/8.1-event-contract",
  "pr_number": 128,
  "pr_url": "https://github.com/Hugopeck/track/pull/128",
  "pr_title": "docs(specs): [8.1] define event contract",
  "base_branch": "main",
  "primary_task_id": "8.1"
}
```

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "track.event.pr.opened.v1",
  "type": "object",
  "properties": {
    "type": { "const": "track.pr.opened" },
    "version": { "type": "string", "const": "1" },
    "timestamp": { "type": "string", "format": "date-time" },
    "repo": { "type": "string", "minLength": 1 },
    "branch": { "type": "string", "minLength": 1 },
    "pr_number": { "type": "integer" },
    "pr_url": { "type": "string", "format": "uri" },
    "pr_title": { "type": "string", "minLength": 1 },
    "base_branch": { "type": "string", "minLength": 1 },
    "primary_task_id": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+$"
    }
  },
  "required": [
    "type",
    "version",
    "timestamp",
    "repo",
    "branch",
    "pr_number",
    "pr_url",
    "pr_title",
    "base_branch",
    "primary_task_id"
  ]
}
```

Semantics: emitted when a draft PR is opened. `branch` is the PR head branch. `primary_task_id` is the emitter's declared primary task.

## `track.pr.ready`

Purpose: record that a PR left draft state and entered review.

### Example

```json
{
  "type": "track.pr.ready",
  "version": "1",
  "timestamp": "2026-03-30T10:00:00Z",
  "repo": "Hugopeck/track",
  "branch": "task/8.1-event-contract",
  "pr_number": 128,
  "pr_url": "https://github.com/Hugopeck/track/pull/128",
  "pr_title": "docs(specs): [8.1] define event contract",
  "base_branch": "main",
  "primary_task_id": "8.1"
}
```

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "track.event.pr.ready.v1",
  "type": "object",
  "properties": {
    "type": { "const": "track.pr.ready" },
    "version": { "type": "string", "const": "1" },
    "timestamp": { "type": "string", "format": "date-time" },
    "repo": { "type": "string", "minLength": 1 },
    "branch": { "type": "string", "minLength": 1 },
    "pr_number": { "type": "integer" },
    "pr_url": { "type": "string", "format": "uri" },
    "pr_title": { "type": "string", "minLength": 1 },
    "base_branch": { "type": "string", "minLength": 1 },
    "primary_task_id": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+$"
    }
  },
  "required": [
    "type",
    "version",
    "timestamp",
    "repo",
    "branch",
    "pr_number",
    "pr_url",
    "pr_title",
    "base_branch",
    "primary_task_id"
  ]
}
```

Semantics: emitted when the PR leaves draft state. This reuses the same identity shape as `track.pr.opened`.

## `track.pr.merged`

Purpose: record that a PR merged into its base branch.

### Example

```json
{
  "type": "track.pr.merged",
  "version": "1",
  "timestamp": "2026-03-30T11:30:00Z",
  "repo": "Hugopeck/track",
  "branch": "task/8.1-event-contract",
  "pr_number": 128,
  "pr_url": "https://github.com/Hugopeck/track/pull/128",
  "pr_title": "docs(specs): [8.1] define event contract",
  "base_branch": "main",
  "primary_task_id": "8.1",
  "merged_commit_sha": "fedcba654321"
}
```

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "track.event.pr.merged.v1",
  "type": "object",
  "properties": {
    "type": { "const": "track.pr.merged" },
    "version": { "type": "string", "const": "1" },
    "timestamp": { "type": "string", "format": "date-time" },
    "repo": { "type": "string", "minLength": 1 },
    "branch": { "type": "string", "minLength": 1 },
    "pr_number": { "type": "integer" },
    "pr_url": { "type": "string", "format": "uri" },
    "pr_title": { "type": "string", "minLength": 1 },
    "base_branch": { "type": "string", "minLength": 1 },
    "primary_task_id": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+$"
    },
    "merged_commit_sha": { "type": "string", "minLength": 1 }
  },
  "required": [
    "type",
    "version",
    "timestamp",
    "repo",
    "branch",
    "pr_number",
    "pr_url",
    "pr_title",
    "base_branch",
    "primary_task_id",
    "merged_commit_sha"
  ]
}
```

Semantics: emitted at merge completion. `timestamp` reflects merge time.

## `track.task.started`

Purpose: record that work on a specific task became active.

### Example

```json
{
  "type": "track.task.started",
  "version": "1",
  "timestamp": "2026-03-30T09:10:00Z",
  "repo": "Hugopeck/track",
  "branch": "task/8.1-event-contract",
  "task_id": "8.1",
  "start_reason": "explicit_start"
}
```

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "track.event.task.started.v1",
  "type": "object",
  "properties": {
    "type": { "const": "track.task.started" },
    "version": { "type": "string", "const": "1" },
    "timestamp": { "type": "string", "format": "date-time" },
    "repo": { "type": "string", "minLength": 1 },
    "branch": { "type": "string", "minLength": 1 },
    "task_id": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+$"
    },
    "start_reason": {
      "type": "string",
      "enum": ["explicit_start", "first_commit"]
    }
  },
  "required": [
    "type",
    "version",
    "timestamp",
    "repo",
    "branch",
    "task_id",
    "start_reason"
  ]
}
```

Semantics: emitted when task work becomes active. This can be emitted by the unified `track` flow or inferred from a first task commit.

## `track.link`

Purpose: record manual retroactive attribution for activity on the current branch.

### Example

```json
{
  "type": "track.link",
  "version": "1",
  "timestamp": "2026-03-30T12:00:00Z",
  "repo": "Hugopeck/track",
  "branch": "feature/retroactive-link",
  "task_id": "8.1",
  "link_mode": "branch_history"
}
```

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "track.event.link.v1",
  "type": "object",
  "properties": {
    "type": { "const": "track.link" },
    "version": { "type": "string", "const": "1" },
    "timestamp": { "type": "string", "format": "date-time" },
    "repo": { "type": "string", "minLength": 1 },
    "branch": { "type": "string", "minLength": 1 },
    "task_id": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+$"
    },
    "link_mode": {
      "type": "string",
      "const": "branch_history"
    }
  },
  "required": [
    "type",
    "version",
    "timestamp",
    "repo",
    "branch",
    "task_id",
    "link_mode"
  ]
}
```

Semantics: v1 supports retroactive linking for current branch history only. This is the manual attribution signal.

## Attribution Result Model

Future consumers (batch scripts, Cloud) may enrich events with attribution after ingestion. This attribution model is separate from the wire payloads above.

### Attribution semantics

- `task_id: null` means untracked activity, not lost activity
- All events are stored whether they are attributed or not
- `manual` attribution comes from `track.link`
- `matched_branch` and `matched_scope` come from deterministic matching
- `llm_inferred` is used only for ambiguous or unmatched events
- `attribution_source: null` pairs with `task_id: null` for fully untracked records

### Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "track.event.attribution.v1",
  "type": "object",
  "properties": {
    "task_id": {
      "type": ["string", "null"],
      "pattern": "^[0-9]+\\.[0-9]+$"
    },
    "attribution_source": {
      "type": ["string", "null"],
      "enum": ["matched_branch", "matched_scope", "llm_inferred", "manual", null]
    },
    "confidence": {
      "type": ["number", "null"],
      "minimum": 0,
      "maximum": 1
    },
    "reasoning": {
      "type": ["string", "null"]
    }
  },
  "required": ["task_id", "attribution_source", "confidence", "reasoning"]
}
```

## Versioning and Compatibility

- `version` is a string and begins at `"1"`
- Optional additive fields are allowed within a version
- Field removals, renames, enum-breaking changes, or semantic redefinitions require a new version
- Consumers should ignore unknown optional fields when possible
- All examples in this document use `version: "1"`

## Downstream References

- Task `8.3` implements hook emitters against the wire event schemas in this document
- Task `8.5` emits `track.task.started` and `track.link`
- Server architecture spec (`.track/specs/server-architecture.md`, superseded) describes a future runtime that would consume these payloads
