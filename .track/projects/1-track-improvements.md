---
id: "1"
title: "Track Improvements"
priority: high
status: active
created: 2026-03-30
updated: 2026-03-30
---

# Track Improvements

## Goal
Improve Track's robustness, usability, and feature set based on real-world usage.

## Why Now
Track is at v1.0.0 and actively dogfooding itself. Early improvements compound as more repos adopt.

## In Scope
- New status types and task lifecycle features
- Test coverage and CI enforcement
- Quality-of-life skills and scripts

## Out Of Scope
- Web UI or dashboard
- Switching away from bash scripts
- Config files or `.trackrc`

## Shared Context
Track is a skill-first project distributed as markdown skills + bash scripts. Adopting repos are self-contained.

## Dependency Notes
None.

## Success Definition
Track handles real-world coordination patterns (blocking, cancellation, archival) without requiring manual file editing for common operations.

## Candidate Task Seeds
- Blocked status field
- Task archival
- Filtered TODO generation
- `/track:cancel` skill
