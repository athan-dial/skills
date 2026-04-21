#!/usr/bin/env bash
# Install orc skills into ~/.claude/skills/
# Usage: bash install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

echo "Installing orc skills to $SKILLS_DIR"

for skill_dir in "$SCRIPT_DIR"/skills/orc*; do
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_DIR/$skill_name"

  if [ -d "$target" ]; then
    echo "  Updating $skill_name"
    rm -rf "$target"
  else
    echo "  Installing $skill_name"
  fi

  cp -r "$skill_dir" "$target"
done

# Make scripts executable
find "$SKILLS_DIR"/orc*/scripts -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

echo ""
echo "Installed $(ls -d "$SKILLS_DIR"/orc* 2>/dev/null | wc -l | tr -d ' ') orc skills."
echo "Start a new Claude Code session to pick them up."
echo ""
echo "Available commands:"
echo "  orc:dispatch       Multi-agent execution"
echo "  orc:orchestrate    Alias for dispatch (legacy)"
echo "  orc:backlog        add/list/triage/pick/drop"
echo "  orc:autoresearch   Autonomous metric optimization"
echo "  orc:scope          Shape idea into plan"
echo "  orc:status         Dashboard"
echo "  orc:recap          Session-start briefing"
echo "  orc:handoff        Crash recovery checkpoint"
