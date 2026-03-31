---
id: "8"
title: "Track-OSS Alignment"
priority: high
status: active
created: 2026-03-30
updated: 2026-03-31
---

# Track-OSS Alignment

## Goal
Reshape this repo into a pure protocol foundation: event-driven automation via hooks and GitHub workflows, skill refinement, event contract, git hook templates, and GitHub Rulesets. No server, no runtime — Track stays markdown skills + bash scripts + git hooks.

## Why Now
The current skill set needs targeted extensions (link/context modes) and the protocol needs event infrastructure (hooks, JSONL logging, workflow automation) to support untracked activity and cascade unblocks without a server.

## In Scope
- Event contract specification for Track components in this repo
- Deterministic scope matching in track-common.sh
- Git hook templates (commit-msg linter + post-commit event emitter)
- GitHub Ruleset template for init
- Skill refinement: extend work with link/context, optional thin dispatcher
- Cascade unblocks via post-merge GitHub workflow
- Documentation updates (TRACK.md, README.md, AGENTS.md)

## Out of Scope
- Local server/runtime (deferred to Cloud)
- Existing tasks in projects 1–7 (untouched)

## Success Definition
- `.track/specs/event-contract.md` defines all event types and payloads
- Hook templates produce valid JSON events to JSONL log
- Work skill handles link and context modes
- Init skill deploys hooks + rulesets
- Post-merge workflow cascades unblocks automatically
- All existing tests still pass
