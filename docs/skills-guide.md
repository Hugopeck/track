# Building cross-platform agent skills and plugins

An opinionated guide for solo developers building, distributing, and updating agent skills and vendor plugins across Claude Code, Codex, and OpenCode.

---

## Core concepts

### Skills vs plugins

**Skills** are portable knowledge packages. A directory with a `SKILL.md` file, optional scripts, references, and assets. They follow the open Agent Skills specification (agentskills.io) and work across Claude Code, Codex, and OpenCode without modification.

**Plugins** are vendor-specific apps. They wrap skills with lifecycle hooks, custom agents, commands, MCP servers, and marketplace metadata. Each vendor has its own plugin format. There is no universal plugin spec.

Skills are the content. Plugins are the delivery mechanism. Build skills first, wrap into plugins only when you need hooks or marketplace distribution.

### The universal skill format

```text
skill-name/
├── SKILL.md          # Required: YAML frontmatter + markdown instructions
├── scripts/          # Optional: executable code (runs via bash, output enters context)
├── references/       # Optional: documentation (read into context on demand)
└── assets/           # Optional: templates, schemas, static resources
```

`SKILL.md` must have YAML frontmatter with `name` (lowercase, hyphens, max 64 chars) and `description` (max 1024 chars). The markdown body contains instructions the agent follows when activated.

```yaml
---
name: my-skill
description: What this skill does and when to use it. Include trigger keywords.
---

Instructions for the agent.
```

Optional frontmatter: `license`, `compatibility` (environment requirements), `metadata` (key-value pairs), `allowed-tools` (experimental).

### Progressive disclosure

Skills load in three tiers:

1. **Catalog** (~50-100 tokens per skill): name + description, loaded at session start.
2. **Instructions** (<5,000 tokens): full SKILL.md body, loaded on activation.
3. **Resources** (varies): scripts/references/assets, loaded only when instructions reference them.

Scripts are especially efficient — the agent runs them and only the output enters context. The source code stays on disk.

---

## Convention: AGENTS.md as primary, CLAUDE.md points to it

Use `AGENTS.md` as the primary agent instruction file. It's the cross-platform convention — Claude Code, Codex, Cursor, Gemini CLI, and OpenCode all read it. Add a thin `CLAUDE.md` that redirects:

**CLAUDE.md** (at repo root):

```markdown
See @AGENTS.md
```

**AGENTS.md** (at repo root):

````markdown
# Track

File-based task management for solo developers orchestrating AI coding agents.

## Project structure

- `skills/` — Installable agent skills (each subdirectory is a standalone skill)
- `tests/` — Eval queries for skill triggering accuracy
- `docs/` — Design decisions, architecture notes

## Development

When working on skills in this repo, follow the Agent Skills spec:
- Each installable skill is self-contained in its own directory under `skills/`
- Installable skills are discovered by `SKILL.md`, not by raw directory count
- `SKILL.md` frontmatter must have `name` and `description`
- Use `references/`, `scripts/`, and `assets/` only when they carry real content

## Commands

- Run evals: `python tests/run_evals.py`
- Validate skill: `skills-ref validate ./skills/<name>`

## Updating installed skills

If you have Track skills installed, run `/update-skills` or:
```bash
cd <track-repo> && git pull --ff-only
```
````

This way, every agent that enters your repo — regardless of vendor — gets the same instructions. Claude Code reads `CLAUDE.md` which points to `AGENTS.md`. Codex reads `AGENTS.md` directly. Everyone sees the same content.

---

## Project structure: one repo per project, multiple skills per repo

A project is a set of related skills that share a domain. Each project gets its own repo.

### Example: Track project

```text
track/                              # repo root
├── AGENTS.md                       # Primary agent instructions (cross-platform)
├── CLAUDE.md                       # Points to @AGENTS.md
├── README.md                       # Human-facing docs, install instructions
├── LICENSE
│
├── skills/
│   ├── init/
│   │   ├── SKILL.md
│   │   └── assets/
│   │       ├── install-manifest.json
│   │       ├── track-readme.md
│   │       └── workflows/
│   ├── work/
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── track-pr-lint.sh
│   │       └── track-complete.sh
│   ├── validate/
│   │   └── scripts/
│   │       ├── track-validate.sh
│   │       └── track-conventional-commit-lint.sh
│   ├── todo/
│   │   ├── SKILL.md                 # ships /track:refresh-track
│   │   └── scripts/
│   │       └── track-todo.sh
│   ├── create/SKILL.md
│   ├── decompose/SKILL.md
│   ├── update-track/SKILL.md        # ships /update-skills
│   └── runtime/                     # internal shared support, not a skill
│       └── scripts/
│           └── track-common.sh
│
├── tests/
│   ├── test-validate.sh
│   ├── test-todo.sh
│   └── test-complete.sh
│
└── .github/
    └── workflows/
        └── update-plugins.yml      # Pushes skill changes to plugin repos
```

### Naming conventions

- Repo name usually matches the project/domain (`track`, `archeia`).
- Skills are peers named for capabilities or workflows (`init`, `work`, `create`, `decompose`). Utility skills may keep implementation-oriented directory names (`todo/` ships `/track:refresh-track`, `update-track/` ships `/update-skills`).
- Project prefixes are optional; use them only when they improve clarity or prevent collisions.

Auto-loading is not hierarchy. In Track, `work` auto-loads in repos with `.track/`,
but it is still a peer skill rather than a parent or "core" skill.

### Why `skills/` subdirectory

The repo root holds dev infrastructure: AGENTS.md, README, LICENSE, tests, CI. Installable skills live under `skills/`. Users install from `skills/`, not the repo root. This keeps development context cleanly separated from distributed content.

### Source ownership vs deployed runtime

These are separate decisions:

- **Source ownership** lives with the skill that defines the behavior.
- **Deployed runtime** can still be assembled into the adopting repo.

Track uses this split deliberately: `validate`, `todo`, and `work` own their
runtime scripts in the skill repo, while `/track:init` assembles those sources
into `.track/scripts/` so local commands and GitHub workflows keep stable repo-local paths.

---

## Installing skills

The install script clones the repo once into a stable location and creates symlinks so every agent client can discover the skills.

### Install script (include in your repo as `install.sh`)

```bash
#!/bin/bash
# install.sh — Install Track skills via full clone
set -e

REPO_URL="${1:-https://github.com/hugo/track.git}"
CLONE_DIR="${HOME}/.local/share/agent-skills/track"
INSTALL_DIR="${HOME}/.agents/skills"

mkdir -p "$INSTALL_DIR"

if [ -d "$CLONE_DIR/.git" ]; then
  echo "Updating existing installation..."
  cd "$CLONE_DIR" && git pull --ff-only
else
  echo "Installing Track skills..."
  git clone "$REPO_URL" "$CLONE_DIR"
fi

# Symlink each installable skill into the cross-platform discovery path
for skill in "$CLONE_DIR/skills"/*/; do
  [ -f "$skill/SKILL.md" ] || continue
  name="$(basename "$skill")"
  ln -sfn "$skill" "$INSTALL_DIR/$name"
  echo "  Installed $name → $INSTALL_DIR/$name"
done

# Also symlink into Claude Code's native skills path
CLAUDE_INSTALL_DIR="${HOME}/.claude/skills"
mkdir -p "$CLAUDE_INSTALL_DIR"
for skill in "$CLONE_DIR/skills"/*/; do
  [ -f "$skill/SKILL.md" ] || continue
  name="$(basename "$skill")"
  ln -sfn "$skill" "$CLAUDE_INSTALL_DIR/$name"
done

echo "Done. Skills available on next agent session."
```

Usage:

```bash
# Default (your repo)
curl -sSL https://raw.githubusercontent.com/hugo/track/main/install.sh | bash

# Or clone and run
git clone https://github.com/hugo/track.git /tmp/track
bash /tmp/track/install.sh
```

### How it works

The full repo clones once to `~/.local/share/agent-skills/track/`. Symlinks in the discovery paths point into it — lightweight pointers, nothing duplicated. When the `update-skills` skill runs `git pull` in the clone, all symlinks immediately reflect the updated content.

```text
~/.local/share/agent-skills/track/   ← one real clone (git pull updates this)
~/.agents/skills/work → ...track/skills/work/    ← cross-client discovery
~/.claude/skills/work → ...track/skills/work/    ← Claude Code native path
```

Internal support directories can exist under `skills/`, but only folders with `SKILL.md` are installable skills.

### Where skills get installed

| Scope         | Path                        | Effect                   |
| ------------- | --------------------------- | ------------------------ |
| User-level    | `~/.agents/skills/`         | Available in all projects (cross-client) |
| User-level    | `~/.claude/skills/`         | Available in all projects (Claude Code native) |
| Project-level | `<project>/.agents/skills/` | Available in one project |

---

## Keeping skills updated

### The self-updating skill (primary mechanism)

Every project should include an update skill. The user invokes `/update-skills` and the agent pulls the latest:

````markdown
---
name: update-skills
description: Update Track skills to latest version. Use when asked to update Track or check for updates.
disable-model-invocation: true
---

Run the update:

1. Find the Track repo by following the symlink:
   ```bash
   SKILL_DIR="$(dirname "$(readlink -f "$(pwd)")")"
   REPO="$(cd "$SKILL_DIR/.." && git rev-parse --show-toplevel 2>/dev/null)"
   ```

2. Pull latest:
   ```bash
   cd "$REPO" && git pull --ff-only
   ```

3. Report changes:
   ```bash
   cd "$REPO" && echo "Updated to $(git rev-parse --short HEAD)" && git log --oneline -5
   ```

If the pull fails due to local changes, inform the user and suggest:
`git stash && git pull && git stash pop`
````

This works identically across Claude Code, Codex, and OpenCode — it's just bash inside a SKILL.md.

### Auto-update via AGENTS.md

Add a section to the user's global `AGENTS.md` (at `~/.agents/AGENTS.md` or `~/AGENTS.md`) that tells agents to check for skill updates:

````markdown
## Skill maintenance

At the start of each session, if idle or between tasks, check for skill updates:
```bash
for repo in ~/.local/share/agent-skills/*/; do
  (cd "$repo" && git pull --ff-only 2>/dev/null) &
done
wait
```

Do not report results unless updates were found.
````

This is a soft convention — the agent reads it and may or may not act on it depending on context. For guaranteed execution, use a SessionStart hook (see the plugin section).

### Scheduled auto-update (background)

For fire-and-forget freshness:

```bash
# crontab -e
0 9 * * * for d in ~/.local/share/agent-skills/*/; do (cd "$d" && git pull --ff-only 2>/dev/null); done
```

### Version pinning

For stability over freshness:

```bash
cd ~/.local/share/agent-skills/track && git checkout v1.2.0
```

Tag releases in your skill repo with semver.

---

## Plugin architecture (when you need hooks)

When a project needs lifecycle hooks, custom agents, or marketplace distribution, it becomes a plugin. The plugin is a separate repo that consumes skills from the project repo.

### When you need a plugin

| Capability                        | Raw skills | Plugin required |
| --------------------------------- | ---------- | --------------- |
| Instructions, scripts, references | ✓          | —               |
| SessionStart context loading      | —          | ✓               |
| PreToolUse/PostToolUse validation | —          | ✓               |
| Custom sub-agents                 | —          | ✓               |
| Marketplace distribution          | —          | ✓               |
| MCP server configuration          | —          | ✓               |

### Claude Code plugin

```text
track-claude-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/                        # Copied from track repo via CI
│   ├── work/
│   │   └── SKILL.md
│   ├── validate/
│   │   └── SKILL.md
│   └── todo/
│       └── SKILL.md
├── hooks/
│   └── hooks.json                 # Claude Code lifecycle hooks
├── agents/
│   └── task-decomposer.md
├── commands/
│   └── sprint.md
└── .mcp.json
```

**plugin.json:**

```json
{
  "name": "track",
  "version": "1.0.0",
  "description": "Task management for solo developers orchestrating AI agents",
  "author": { "name": "Hugo" },
  "skills": "./skills/",
  "interface": {
    "displayName": "Track",
    "shortDescription": "File-based task management for AI agents",
    "category": "Productivity"
  }
}
```

**hooks.json:**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/load_active_tasks.sh",
            "statusMessage": "Loading active tasks"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Check if any tasks should be updated based on what was accomplished. If so, update the task status files in .track/.",
            "timeout": 30
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "If writing to a .track/ task file, validate the YAML frontmatter matches the task schema. Return 'approve' if valid, 'deny' with reason if not."
          }
        ]
      }
    ]
  }
}
```

### Codex plugin

```text
track-codex-plugin/
├── .codex-plugin/
│   └── plugin.json
├── skills/                        # Same skills, copied from track repo
│   ├── work/
│   │   ├── SKILL.md
│   │   └── agents/
│   │       └── openai.yaml        # Codex-specific UI metadata
│   ├── validate/
│   │   └── SKILL.md
│   └── todo/
│       └── SKILL.md
└── hooks/
    └── hooks.json                  # Codex hooks (command-only, no prompt type)
```

**Codex hooks (command-only — no prompt-based hooks):**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "python3 scripts/load_active_tasks.py",
            "statusMessage": "Loading active tasks"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 scripts/check_task_updates.py",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**agents/openai.yaml (optional per-skill Codex metadata):**

```yaml
interface:
  display_name: "Track"
  short_description: "Task management for AI agents"
  brand_color: "#3B82F6"

policy:
  allow_implicit_invocation: true
```

### OpenCode plugin

OpenCode plugins are JS/TS modules — architecturally different:

```text
track-opencode-plugin/
├── package.json
├── src/
│   └── index.ts
└── skills/                        # Same skills, copied
    ├── work/
    │   └── SKILL.md
    ├── validate/
    │   └── SKILL.md
    └── todo/
        └── SKILL.md
```

```typescript
import type { Plugin } from "@opencode-ai/plugin"

export const TrackPlugin: Plugin = async ({ project, client, $, directory }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.created") {
        const tasks = await $`find ${directory}/.track -name "*.md" -path "*/active/*" 2>/dev/null`
        // Load active task context
      }
    },
    "tool.execute.before": async (input, output) => {
      if (input.tool === "write" && output.args.filePath?.includes(".track/")) {
        // Validate task file YAML
      }
    },
  }
}
```

---

## Hooks compatibility matrix

| Feature            | Claude Code               | Codex                  | OpenCode                  |
| ------------------ | ------------------------- | ---------------------- | ------------------------- |
| Config format      | JSON (`hooks.json`)       | JSON (`hooks.json`)    | JS/TS module exports      |
| Hook types         | command + prompt          | command only           | async event handlers      |
| PreToolUse scope   | Write, Edit, Bash, etc.   | Bash only (currently)  | `tool.execute.before`     |
| PostToolUse scope  | Write, Edit, Bash, etc.   | Bash only (currently)  | `tool.execute.after`      |
| SessionStart       | `startup`, `resume`       | `startup`, `resume`    | `session.created`         |
| Stop/Idle          | Stop event                | Stop event             | `session.idle`            |
| User prompt        | `UserPromptSubmit`        | `UserPromptSubmit`     | `tui.prompt.append`       |
| Prompt-based hooks | ✓ (LLM validates actions) | ✗                      | ✗ (call LLM in JS manually) |
| Matcher patterns   | regex on tool name        | regex on tool name     | conditional logic in code |
| Plugin root var    | `${CLAUDE_PLUGIN_ROOT}`   | git rev-parse pattern  | context object            |

**Claude Code's prompt-based hooks** are a key differentiator. Having an LLM validate tool calls in real time — `"type": "prompt"` — is something only Claude Code supports natively. For Codex, you'd replicate this with a deterministic validation script.

---

## Getting skills from project repo into plugin repos

A GitHub Action on the project repo copies skill files into each plugin repo on push:

```yaml
# In track/.github/workflows/update-plugins.yml
name: Update plugin repos
on:
  push:
    branches: [main]
    paths: ['skills/**']

jobs:
  update-claude-plugin:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Push skills to Claude plugin repo
        run: |
          git clone https://x-access-token:${{ secrets.PAT }}@github.com/hugo/track-claude-plugin.git /tmp/plugin
          rm -rf /tmp/plugin/skills
          cp -r skills /tmp/plugin/skills
          cd /tmp/plugin
          git config user.name "github-actions"
          git config user.email "actions@github.com"
          git add skills/
          if git diff --cached --quiet; then
            echo "No skill changes"
            exit 0
          fi
          SKILL_SHA=$(git -C $GITHUB_WORKSPACE rev-parse --short HEAD)
          git commit -m "chore: update skills from track@${SKILL_SHA}"
          git push

  update-codex-plugin:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Push skills to Codex plugin repo
        run: |
          git clone https://x-access-token:${{ secrets.PAT }}@github.com/hugo/track-codex-plugin.git /tmp/plugin
          rm -rf /tmp/plugin/skills
          cp -r skills /tmp/plugin/skills
          cd /tmp/plugin
          git config user.name "github-actions"
          git config user.email "actions@github.com"
          git add skills/
          git diff --cached --quiet || (git commit -m "chore: update skills from track@$(git -C $GITHUB_WORKSPACE rev-parse --short HEAD)" && git push)
```

The commit message includes the skill repo SHA for traceability. No submodules, no ceremony.

---

## End-user plugin updates

### Claude Code

Add a SessionStart hook for auto-update:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "cd \"${CLAUDE_PLUGIN_ROOT}\" && git pull --ff-only 2>/dev/null || true",
            "timeout": 10,
            "statusMessage": "Checking for updates"
          }
        ]
      }
    ]
  }
}
```

### Codex

Same pattern:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "PLUGIN_DIR=$(git rev-parse --show-toplevel 2>/dev/null) && cd \"$PLUGIN_DIR\" && git pull --ff-only 2>/dev/null || true",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

### OpenCode

npm plugins update via `bun update`. Local plugins reload on restart — no mechanism needed beyond pulling the latest files.

---

## The full picture

```text
Development repos:

  github.com/hugo/track              # skills + dev context
  github.com/hugo/archeia            # skills + dev context

Distribution (skills only, no plugin):

  User runs install.sh → full clone → symlinks in ~/.agents/skills/ + ~/.claude/skills/
  User updates via /update-skills or cron

Distribution (plugins, when hooks are needed):

  github.com/hugo/track-claude-plugin    # wraps skills + hooks + agents
  github.com/hugo/track-codex-plugin     # wraps skills + hooks

  CI copies skills/ from track repo → plugin repos on every push
  Users install via marketplace or /plugin install
  SessionStart hook auto-updates on each session
```

---

## Checklist: starting a new skill project

1. Create the repo with `skills/` directory.
2. Add `AGENTS.md` as primary instructions. Add `CLAUDE.md` containing `See @AGENTS.md`.
3. Create one `SKILL.md` per capability or workflow.
4. Use `scripts/`, `references/`, and `assets/` only when they carry real content.
5. If you keep internal support directories under `skills/`, omit `SKILL.md` so discovery skips them.
6. Include `install.sh` (full clone + symlinks into `~/.agents/skills/` and `~/.claude/skills/`) and an `update-<project>` skill.
7. Add eval queries in `tests/`.
8. Tag releases with semver when skills stabilize.
9. Create plugin repos only when you need hooks, agents, or marketplace distribution.
10. Set up CI to copy skills from project repo → plugin repos on push.
11. Add SessionStart auto-update hooks in plugin repos.
