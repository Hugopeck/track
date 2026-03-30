---
id: "8"
title: "Track-OSS Alignment"
priority: high
status: active
created: 2026-03-30
updated: 2026-03-30
---

# Track-OSS Alignment

## Goal
Reshape this repo into the Track OSS foundation: two-product model (OSS + Cloud), unified skill interface, event contract, git hook templates, and GitHub Rulesets. Define the local server architecture (Bun/TS) so Track's emitters and runtime share the same contract.

## Why Now
The current 9-skill, agent-driven lifecycle model doesn't scale. Server-side detection with LLM inference is the right architecture. This alignment sets the foundation before building the server.

## In Scope
- Event contract specification for Track components in this repo
- Deterministic scope matching in track-common.sh
- Git hook templates (commit-msg linter + post-commit event emitter)
- GitHub Ruleset template for init
- Skill consolidation: 9 → 2 (unified `track` + `init`)
- Documentation updates (TRACK.md, README.md, AGENTS.md)
- Server architecture definition (Bun/TS, SQLite schema, API routes, LLM integration)

## Out of Scope
- Building the local Track server/runtime
- Track Cloud (managed hosting)
- Dashboard implementation
- Existing tasks in projects 1–7 (untouched)

## Success Definition
- `.track/specs/event-contract.md` defines all event types and payloads
- Hook templates produce valid JSON events
- Unified `track` skill handles create/start/work/decompose/link/status
- Init skill deploys hooks + rulesets
- Server architecture is documented with enough detail to start building
- All existing tests still pass
