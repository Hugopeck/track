# r/ClaudeAI Post

**Subreddit:** r/ClaudeAI
**When:** Day 2 of launch week
**Flair:** Tool/Resource (check subreddit rules)

---

## Title

I built a Claude Code plugin that coordinates multiple agents working on the same repo

## Body

I've been running multiple Claude Code agents in parallel (via Conductor) and kept hitting the same problem: agents would edit the same files, create conflicting PRs, and waste tokens on duplicate work.

So I built Track — a Claude Code plugin that adds task coordination to your repo. Here's how it works:

**The setup:**
- Run `/track:init` in any repo
- It creates a `.track/` folder with markdown task files
- Each task has a `files:` field listing which files it'll touch

**How agents coordinate:**
- When an agent runs `/track:work`, it reads TODO.md, picks a task that isn't blocked, checks BOARD.md if it needs context, and starts working
- Other agents see which files are claimed and pick different tasks
- PR state drives status automatically (draft = active, merged = done)

**What it looks like:**
```yaml
---
id: "1.3"
title: "Add user authentication"
status: todo
files: [src/auth.ts, src/middleware.ts]
depends_on: ["1.1", "1.2"]
---
```

No server, no database — just markdown files in your git repo.

It also works with Cursor, Codex, and Gemini CLI since it's just files + bash scripts.

GitHub: https://github.com/Hugopeck/track

Install: `claude plugin install hugopeck/track`

Would love feedback from anyone running multi-agent workflows. What coordination problems are you hitting?
