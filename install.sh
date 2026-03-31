#!/bin/bash
# install.sh — Install Track skills via full clone
set -e

REPO_URL="${1:-https://github.com/Hugopeck/track.git}"
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

# Symlink each skill into the cross-platform discovery path
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
