# Phase 2: Create `track-claude-plugin` repo

## Background

Track was reorganized into two concerns:

1. **track** (`Hugopeck/track`) — the skill project. Contains `skills/`, `TRACK.md`, `install.sh`, scripts, tests, growth docs. No `.claude-plugin/` directory.
2. **track-claude-plugin** (`Hugopeck/track-claude-plugin`) — a thin Claude Code plugin wrapper. Packages Track skills so users can install via `claude plugin add Hugopeck/track-claude-plugin`.

## What a Claude Code plugin needs

- `.claude-plugin/plugin.json` at root with name, description, version, homepage, author
- A `skills/` directory containing skill subdirectories, each with a `SKILL.md`

No build step. Claude Code discovers skills by walking `skills/*/SKILL.md`.

## Target layout

```
track-claude-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/                   # Copied from track/ by CI
│   ├── init/
│   │   ├── SKILL.md
│   │   └── assets/           # Scripts, workflows, conductor files, readmes
│   ├── work/SKILL.md
│   ├── create/SKILL.md
│   ├── decompose/SKILL.md
│   ├── validate/SKILL.md
│   ├── todo/SKILL.md
│   ├── test/SKILL.md
│   └── update-track/SKILL.md
├── TRACK.md                  # Copied from track/ root (init references via relative path)
├── .github/workflows/
│   └── sync-skills.yml
├── README.md
└── LICENSE
```

## Steps

### 1. Create the GitHub repo

```bash
gh repo create Hugopeck/track-claude-plugin --public \
  --description "Claude Code plugin wrapper for Track — git-native task coordination"
```

Clone it locally and work from there.

### 2. Create `.claude-plugin/plugin.json`

```json
{
  "name": "track",
  "description": "Invisible task coordination for Claude Code. Turns your git repo into a self-managing project system — markdown tasks, PR-driven status, zero dependencies.",
  "version": "2.4.0",
  "homepage": "https://github.com/Hugopeck/track",
  "author": {
    "name": "Hugo Peck"
  }
}
```

### 3. Copy skills from the track repo

Copy the entire `skills/` directory from the track repo (`main` branch after belgrade-v1 merges). Include all subdirectories and contents — `init/assets/` has scripts, workflows, conductor config, and readmes that must travel with the skill.

Copy `TRACK.md` from track repo root into this repo's root. The init skill references it via `${CLAUDE_SKILL_DIR}/../../TRACK.md` — that relative path resolves correctly when `SKILL.md` is at `skills/init/SKILL.md` and `TRACK.md` is at root.

### 4. Create `.github/workflows/sync-skills.yml`

Copies skills from the track source repo on manual dispatch, repository dispatch, or daily schedule.

```yaml
name: Sync Skills from Track

on:
  workflow_dispatch:
  repository_dispatch:
    types: [sync-skills]
  schedule:
    - cron: '0 6 * * *'

permissions:
  contents: write

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Clone track source
        run: git clone --depth 1 https://github.com/Hugopeck/track.git /tmp/track-source

      - name: Sync skills and TRACK.md
        run: |
          rm -rf skills/
          cp -r /tmp/track-source/skills/ skills/
          cp /tmp/track-source/TRACK.md TRACK.md

          TRACK_VERSION=$(python3 -c "import json; print(json.load(open('/tmp/track-source/.release-please-manifest.json'))['.'])")
          python3 -c "
          import json
          with open('.claude-plugin/plugin.json', 'r+') as f:
              data = json.load(f)
              data['version'] = '$TRACK_VERSION'
              f.seek(0)
              json.dump(data, f, indent=2)
              f.write('\n')
              f.truncate()
          "

      - name: Check for changes
        id: diff
        run: git diff --quiet && echo "changed=false" >> "$GITHUB_OUTPUT" || echo "changed=true" >> "$GITHUB_OUTPUT"

      - name: Commit and push
        if: steps.diff.outputs.changed == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add -A
          git commit -m "chore: sync skills from track v${TRACK_VERSION:-latest}"
          git push
```

### 5. Add a dispatch trigger to the track repo (optional)

In the **track** repo, create `.github/workflows/notify-plugin.yml`:

```yaml
name: Notify Plugin Repo

on:
  push:
    branches: [main]
    paths:
      - 'skills/**'
      - 'TRACK.md'

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger plugin sync
        run: |
          gh api repos/Hugopeck/track-claude-plugin/dispatches \
            -f event_type=sync-skills
        env:
          GH_TOKEN: ${{ secrets.PLUGIN_SYNC_TOKEN }}
```

Requires a personal access token (`PLUGIN_SYNC_TOKEN`) with `repo` scope on the plugin repo, stored as a secret in the track repo. Skip if you don't want cross-repo tokens yet — the daily schedule and manual dispatch are sufficient.

### 6. Create README.md

Cover:
- This is the Claude Code plugin wrapper for Track
- Install: `claude plugin add Hugopeck/track-claude-plugin`
- Skills source: https://github.com/Hugopeck/track
- Skills are synced automatically — do not edit skills in this repo
- Link to track repo for docs, issues, contributing

### 7. Add LICENSE

Copy the LICENSE file from the track repo.

### 8. Verify

1. `claude plugin add Hugopeck/track-claude-plugin` — installs the plugin
2. In a test repo: `/track:init` — scaffolds correctly
3. In a test repo: `/track:work` — work skill auto-loads
4. `gh workflow run sync-skills.yml` in the plugin repo — manual dispatch works
5. Relative path check: `${CLAUDE_SKILL_DIR}/../../TRACK.md` from `skills/init/SKILL.md` resolves to root `TRACK.md`

## Constraints

- **Do not edit skills in the plugin repo.** All changes happen in the track repo and flow downstream via sync.
- **Version stays in sync.** The sync workflow reads from track's `.release-please-manifest.json` and writes to `plugin.json`.
- **The `update-track` skill** in the plugin context pulls the plugin repo itself (gets latest synced skills). For standalone installs via `install.sh`, it pulls the track repo directly.
- **`TRACK.md` must be at root** of the plugin repo. The init skill's relative path `${CLAUDE_SKILL_DIR}/../../TRACK.md` depends on this.
