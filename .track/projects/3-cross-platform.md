---
id: "3"
title: "Open-Standard Agent Support"
priority: medium
status: active
created: 2026-03-30
updated: 2026-03-30
---

# Open-Standard Agent Support

## Goal
Keep Track usable as a skill-first, vendor-neutral project through shared skills, shared docs, and repo-root instructions, without shipping vendor plugin packages from this repo.

## Why Now
The repo has already been rescoped to skills-first. Track metadata and docs must stop advertising plugin or marketplace work as core repo scope, or the project brief will keep sending agents toward the wrong implementation surface.

## In Scope
- Shared `AGENTS.md` / `CLAUDE.md` instruction model
- Skill-first install and usage documentation
- Vendor-neutral README and support messaging
- Track/init behavior that scaffolds shared instructions instead of vendor wrappers
- Compatibility framing for agents that consume installed skills or repo-root instructions

## Out Of Scope
- Vendor plugin repos and plugin package scaffolding
- Marketplace submissions
- `.cursor/rules/`
- `.claude-plugin/`, `.codex-plugin/`, or similar repo-local wrappers
- Vendor-specific launch and distribution work

## Shared Context
`skills-guide.md` is now the source of truth for the repo direction: skills are the content, plugins are a separate vendor-specific delivery layer. `PHASE2-PLUGIN-REPO.md` captures the deferred plugin-repo phase for any future marketplace or wrapper work.

## Dependency Notes
Completed work under this project that strengthened shared instructions or vendor-neutral docs remains valid history. Open plugin and marketplace work should be cancelled here and deferred to `PHASE2-PLUGIN-REPO.md` so project 4 and project 5 do not depend on repo-local vendor wrappers.

## Success Definition
Track state no longer treats vendor or plugin work as active in this repo. README describes the repo as skill-first and vendor-neutral. No open task in this repo requires a vendor plugin, package, or marketplace artifact.

## Candidate Task Seeds
- Audit README and support docs for vendor-specific claims
- Keep init guidance centered on shared instructions
- Clarify installed-skills versus repo-root `AGENTS.md` usage paths
- Defer plugin wrapper work to the separate phase documented in `PHASE2-PLUGIN-REPO.md`
