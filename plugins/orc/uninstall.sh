#!/usr/bin/env bash
# Remove orc skills from ~/.claude/skills/
set -euo pipefail

SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

echo "Removing orc skills from $SKILLS_DIR"

for skill_dir in "$SKILLS_DIR"/orc*; do
  if [ -d "$skill_dir" ]; then
    echo "  Removing $(basename "$skill_dir")"
    rm -rf "$skill_dir"
  fi
done

echo "Done. Start a new Claude Code session to reflect the change."
