#!/usr/bin/env bash
# orchestrate-handoff: prepare-handoff
# Emits a paste-ready resume prompt for cursor or codex, based on .orchestrate/state.json.
# Usage: prepare-handoff.sh [cursor|codex]

set -u

TARGET="${1:-cursor}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE="$REPO_ROOT/.orchestrate/state.json"
HANDOFF="$REPO_ROOT/.orchestrate/HANDOFF.md"

if [ ! -f "$STATE" ]; then
  echo "ERROR: $STATE not found. Run checkpoint.sh first." >&2
  exit 1
fi

WAVE=$(python3 -c "import json;print(json.load(open('$STATE')).get('wave',0))")
NEXT=$(python3 -c "import json;print(json.load(open('$STATE')).get('next_action',''))")

case "$TARGET" in
  cursor)
    cat <<EOF
=== PASTE THIS INTO CURSOR AGENT MODE ===

You are taking over an in-flight \`/orchestrate\` run from Claude Code, which hit its usage limit.
Worker daemons (Codex via codex-companion, Cursor agent jobs) may still be running on disk.

Repo: $REPO_ROOT

Step 1 — Read these in order:
  1. $HANDOFF
  2. $STATE
  3. ~/.claude/skills/orchestrate/SKILL.md (for the workflow you're resuming)

Step 2 — Run the resume script:
  cd "$REPO_ROOT"
  bash ~/.claude/skills/orchestrate-handoff/scripts/resume.sh

Step 3 — Re-attach to in-flight jobs (resume.sh prints the exact poll-wave.sh command).
Once polling is up, continue Phase 2 of /orchestrate from wave $WAVE.

Next action recorded by previous orchestrator:
  $NEXT

After your next wave completes, call checkpoint.sh again to keep state fresh.

=== END PASTE ===
EOF
    ;;
  codex)
    cat <<EOF
=== INVOKE codex:rescue WITH THIS PROMPT ===

This is a RESUME of an in-flight /orchestrate run, not a fresh start.
Repo root: $REPO_ROOT

Read first:
  - $HANDOFF
  - $STATE
  - ~/.claude/skills/orchestrate/SKILL.md (Phase 2 workflow)

Then execute:
  cd "$REPO_ROOT" && bash ~/.claude/skills/orchestrate-handoff/scripts/resume.sh

This will re-attach polling on in-flight worker jobs. Continue from wave $WAVE.
Next action: $NEXT

Use the codex-companion runtime for any new dispatches; do not re-dispatch jobs that
resume.sh shows as still-running or recently-completed.

=== END PROMPT ===
EOF
    ;;
  *)
    echo "Usage: $0 [cursor|codex]" >&2
    exit 2
    ;;
esac
