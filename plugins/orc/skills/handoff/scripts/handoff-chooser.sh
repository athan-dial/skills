#!/usr/bin/env bash
# Interactive picker shown in the auto-spawned cmux pane.
# Reads $1 = repo path containing .orchestrate/AUTO-RESUME.txt

set -u
REPO="${1:-$PWD}"
PROMPT_FILE="$REPO/.orchestrate/AUTO-RESUME.txt"
HANDOFF="$REPO/.orchestrate/HANDOFF.md"

clear
cat <<EOF
╭─ orchestrate-handoff ─ auto-triggered ──────────────────────╮
│  Claude Code hit its usage limit during /orchestrate.       │
│  Worker daemons (codex/cursor) may still be running.        │
│  Pick a receiver to resume the orchestrator role.           │
╰─────────────────────────────────────────────────────────────╯

Repo: $REPO
Handoff: $HANDOFF

  [c] Codex (codex CLI with resume prompt pre-injected)
  [r] Cursor agent (cursor agent CLI)
  [k] Fresh Claude Code session (claude in this pane)
  [p] Just print the prompt — I'll handle it
  [s] Skip / dismiss

EOF
read -n 1 -r -p "Choice: " CHOICE
echo
echo

case "$CHOICE" in
  c|C)
    echo "→ Launching codex with handoff prompt..."
    exec codex < "$PROMPT_FILE"
    ;;
  r|R)
    echo "→ Launching cursor agent with handoff prompt..."
    exec cursor agent --print --force --trust --safe < "$PROMPT_FILE"
    ;;
  k|K)
    echo "→ Launching fresh Claude Code session..."
    cd "$REPO"
    exec claude "Resume orchestration. Read $HANDOFF first, then run: bash ~/.claude/skills/orchestrate-handoff/scripts/resume.sh"
    ;;
  p|P)
    echo "=== Resume prompt ==="
    cat "$PROMPT_FILE"
    echo
    echo "=== End prompt ==="
    exec "$SHELL"
    ;;
  s|S|*)
    echo "Dismissed. State remains in $HANDOFF for manual resume."
    sleep 2
    ;;
esac
