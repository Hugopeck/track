# I Replaced Linear with a Folder (and 600 Lines of Bash) — Get Shit Done

**Platform:** DEV.to (cross-post to personal blog)
**Tags:** #opensource #ai #productivity #tutorial
**When:** Days 2-3 of launch week

---

## Draft

Linear just launched [Linear Agent](https://linear.app/next) — their AI that creates issues, writes code, and manages projects. It's impressive. It also costs $16/seat/month and locks your data in their cloud.

I built something different. It's called Track, and it's a folder.

### The Problem

I run 3-5 AI coding agents in parallel using [Conductor](https://conductor.lol). Each agent gets its own git worktree and works on a different task. In theory, it's 5x productivity. In practice, it's chaos:

- Agent A edits `src/auth.ts`. Agent B also edits `src/auth.ts`. Merge conflict.
- Agent C implements the same feature Agent D is working on. Wasted tokens.
- Agent E finishes a task but nobody updates the tracker. Stale state.

I tried using Linear, GitHub Issues, even a shared markdown file. None of them worked because **project management tools are designed for human handoffs, not agent coordination**.

### The Realization

AI agents don't need:
- A web UI (they can't see it)
- Real-time sync (they read files)
- Notifications (they poll state)
- Drag-and-drop Kanban (come on)

AI agents need:
- To know which files are claimed
- To know which tasks are blocked
- To report progress through git, which they already use
- To read and write the same format: **files**

### The Solution: A Folder

Track stores everything in a `.track/` folder in your git repo:

```
.track/
  projects/       # one file per project
  tasks/           # one file per task
```

Each task is a markdown file with YAML frontmatter:

```yaml
---
id: "1.3"
title: "Add user authentication"
status: todo
priority: high
depends_on: ["1.1", "1.2"]
files: [src/auth.ts, src/middleware.ts]
---

## Context
Implement JWT-based auth for the API layer.

## Acceptance Criteria
- [ ] Login endpoint returns JWT
- [ ] Middleware validates tokens
- [ ] Sessions expire after 24 hours
```

The `files` field is the key innovation. When Agent A claims `src/auth.ts`, Agent B sees it's taken and picks a different task. No locks, no permissions — just a declaration that agents respect.

### PR-Driven Status

Here's the part I love most: **you never manually update a task's status**.

```
todo  →  active (draft PR)  →  review (ready PR)  →  done (merged)
```

Track reads your GitHub PR state. Open a draft PR for task 1.3? The task is now "active." Mark it ready for review? "Review." Merge it? "Done." The task file gets updated automatically.

No more "can you move that ticket to done?" conversations.

### The Numbers

- **~600 lines** of bash scripts (bash 3.2+, works on stock macOS)
- **0** external dependencies (just git)
- **0** dollars/month
- **6** Claude Code skills (setup-track, work, create, decompose, validate, todo)
- **4** bash scripts (validate, todo, pr-lint, complete)

### Linear vs Track: An Honest Comparison

Linear is genuinely excellent software. I used it for years. But the paradigm is wrong for AI agents.

| | Linear | Track |
|---|---|---|
| Cost | $8-16/seat/month | Free (MIT) |
| Infrastructure | Cloud SaaS | Your git repo |
| Agent support | Linear Agent only | Claude Code, Cursor, Codex, Gemini CLI |
| Data ownership | Their servers | Your repo, your git history |
| Status updates | Manual or Linear Agent | Automatic from PR state |
| File conflict prevention | No | Yes — `files:` field on every task |
| Works offline | No | Yes (everything is local files) |

### The Bigger Vision

If a folder can coordinate AI agents on a codebase, why not anything?

I've been experimenting with Track for non-code projects:
- Research papers (tasks = sections, files = chapters)
- Event planning (tasks = vendors, venues, logistics)
- Personal goals (tasks = habits, milestones)

The protocol is simple enough that it works for anything. A GitHub account and a folder is your project manager. AI agents are the bookkeepers you never had.

### Try It

```bash
git clone https://github.com/Hugopeck/track.git ~/.local/share/agent-skills/track && ~/.local/share/agent-skills/track/install.sh
```

Then in any repo: `/track:setup-track`

GitHub: https://github.com/Hugopeck/track

Stop managing. Start tracking. Get shit done.

I'm building this in public and would love your feedback. What coordination problems do you hit with AI agents? What would you manage with just a folder?

---

## Publishing notes
- Add code syntax highlighting for all blocks
- Include 2-3 screenshots (terminal showing .track/, BOARD.md, TODO.md, and PROJECTS.md output)
- Cover image: terminal with .track/ folder tree
- Engage with every comment for 48 hours
