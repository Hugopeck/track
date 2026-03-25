# Show HN: Track — git-native task coordination for AI coding agents

**When to post:** Day 2-3 of launch week, morning EST
**URL:** https://github.com/Hugopeck/track

---

## Post text

Track is a task coordination system for AI coding agents (Claude Code, Cursor, Codex, etc.). It's a `.track/` folder in your git repo — markdown task files with YAML frontmatter, bash scripts for validation, and PR-driven status updates.

The problem: when you run multiple AI agents on the same codebase, they edit the same files, create duplicate PRs, and waste compute. Track solves this with a `files:` field on each task that declares which files it touches, so agents know what's available.

It's ~600 lines of bash, zero dependencies beyond git, and works with any agent that can read files. No server, no accounts.

I built this because I was running 3-5 Claude Code agents in parallel via Conductor and kept hitting coordination failures. Linear just launched their own AI agent, which validated the problem — but their answer is still "use our SaaS tool." I think the filesystem is the tool.

Technical details:
- Tasks are markdown files with YAML frontmatter (id, status, priority, files, depends_on)
- Status lifecycle is driven by GitHub PR state: draft=active, ready=review, merged=done
- Bash scripts validate task files, generate a TODO.md summary, and lint PRs
- The plugin teaches AI agents the protocol; the scripts enforce it
- Works standalone (just bash + git) or as a Claude Code / Cursor plugin

Happy to answer questions about the protocol design, multi-agent coordination, or the "PM tools are dead" thesis.

---

## Comment engagement strategy

- Check HN every 2-3 hours for the first 24 hours
- Reply to every question genuinely and technically
- If someone says "I could build this in 30 minutes" — agree, then explain why protocol design choices matter more than implementation
- If someone compares to Linear/Jira — acknowledge their strengths, explain the paradigm difference
- Don't be defensive about criticism — HN rewards humility
