#!/bin/bash
# install.sh — Install Track skills via full clone + copied skill dirs
set -e

REPO_URL="${1:-https://github.com/Hugopeck/track.git}"
CLONE_DIR="${HOME}/.local/share/agent-skills/track"
INSTALL_DIR="${HOME}/.agents/skills"
CLAUDE_INSTALL_DIR="${HOME}/.claude/skills"

mkdir -p "$INSTALL_DIR" "$CLAUDE_INSTALL_DIR"

copy_skill_dir() {
  local source_dir="$1"
  local dest_dir="$2"

  rm -rf "$dest_dir"
  mkdir -p "$(dirname "$dest_dir")"
  cp -R "$source_dir" "$dest_dir"
}

if [ -d "$CLONE_DIR/.git" ]; then
  echo "Updating existing installation..."
  cd "$CLONE_DIR" && git pull --ff-only
else
  echo "Installing Track skills..."
  git clone "$REPO_URL" "$CLONE_DIR"
fi

# Copy each skill into the cross-platform discovery paths
for skill in "$CLONE_DIR/skills"/*/; do
  [ -f "$skill/SKILL.md" ] || continue
  name="$(basename "$skill")"
  copy_skill_dir "$skill" "$INSTALL_DIR/$name"
  copy_skill_dir "$skill" "$CLAUDE_INSTALL_DIR/$name"
  echo "  Installed $name → $INSTALL_DIR/$name and $CLAUDE_INSTALL_DIR/$name"
done

echo "Done. Skills available on next agent session."
