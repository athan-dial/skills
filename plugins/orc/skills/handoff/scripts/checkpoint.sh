#!/usr/bin/env bash
# orchestrate-handoff: checkpoint
# Writes .orc/state.json + .orc/HANDOFF.md from env vars + tasks.json.
# Idempotent. Safe to call any time. Latest checkpoint overwrites prior.

set -u

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DIR="$REPO_ROOT/.orc"
mkdir -p "$DIR"

# Ensure .gitignore covers .orc/
GITIGNORE="$REPO_ROOT/.gitignore"
if [ -f "$GITIGNORE" ]; then
  grep -qxF '.orc/' "$GITIGNORE" || echo '.orc/' >> "$GITIGNORE"
else
  echo '.orc/' > "$GITIGNORE"
fi

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TASKS_JSON="$DIR/tasks.json"
[ -f "$TASKS_JSON" ] || echo '[]' > "$TASKS_JSON"

# Build inflight jobs JSON array from newline-separated triples
INFLIGHT_RAW="${ORCH_INFLIGHT_JOBS:-}"
INFLIGHT_JSON=$(printf '%s\n' "$INFLIGHT_RAW" | awk 'NF>0 {gsub(/"/,"\\\""); printf "%s\"%s\"", (NR>1?",":""), $0}')
INFLIGHT_JSON="[${INFLIGHT_JSON}]"

ROUTING_RAW="${ORCH_ROUTING_FILES:-}"
ROUTING_JSON=$(printf '%s\n' "$ROUTING_RAW" | awk 'NF>0 {gsub(/"/,"\\\""); printf "%s\"%s\"", (NR>1?",":""), $0}')
ROUTING_JSON="[${ROUTING_JSON}]"

# Escape multi-line notes for JSON
esc_json() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }
NOTES_JSON=$(printf '%s' "${ORCH_NOTES:-}" | esc_json)
NEXT_ACTION_JSON=$(printf '%s' "${ORCH_NEXT_ACTION:-}" | esc_json)
PLAN_REF_JSON=$(printf '%s' "${ORCH_PLAN_REF:-unknown}" | esc_json)
WAVE_STATUS_JSON=$(printf '%s' "${ORCH_WAVE_STATUS:-unknown}" | esc_json)

cat > "$DIR/state.json" <<EOF
{
  "version": 1,
  "checkpointed_at": "$NOW",
  "repo_root": "$REPO_ROOT",
  "plan_ref": $PLAN_REF_JSON,
  "wave": ${ORCH_WAVE:-0},
  "wave_status": $WAVE_STATUS_JSON,
  "inflight_jobs": $INFLIGHT_JSON,
  "routing_files": $ROUTING_JSON,
  "next_action": $NEXT_ACTION_JSON,
  "notes": $NOTES_JSON,
  "tasks_file": "$TASKS_JSON"
}
EOF

# Render HANDOFF.md
HANDOFF="$DIR/HANDOFF.md"
{
  echo "# Orchestration Handoff"
  echo
  echo "**Checkpointed:** $NOW"
  echo "**Repo:** \`$REPO_ROOT\`"
  echo "**Plan:** ${ORCH_PLAN_REF:-unknown}"
  echo "**Wave:** ${ORCH_WAVE:-0} (${ORCH_WAVE_STATUS:-unknown})"
  echo
  echo "## Next action"
  echo
  echo "${ORCH_NEXT_ACTION:-_(none recorded)_}"
  echo
  if [ -n "$INFLIGHT_RAW" ]; then
    echo "## In-flight jobs"
    echo
    echo '```'
    printf '%s\n' "$INFLIGHT_RAW" | awk 'NF>0'
    echo '```'
    echo
    echo "Re-attach with:"
    echo '```bash'
    echo "zsh ~/.claude/skills/orchestrate/scripts/poll-wave.sh \\"
    printf '%s\n' "$INFLIGHT_RAW" | awk 'NF>0 {printf "  %s%s\n", $0, (NR==N?"":" \\")}' N=$(printf '%s\n' "$INFLIGHT_RAW" | awk 'NF>0' | wc -l | tr -d ' ')
    echo '```'
    echo
  fi
  if [ -n "$ROUTING_RAW" ]; then
    echo "## Routing context (read these first)"
    echo
    printf '%s\n' "$ROUTING_RAW" | awk 'NF>0 {print "- `" $0 "`"}'
    echo
  fi
  if [ -n "${ORCH_NOTES:-}" ]; then
    echo "## Notes"
    echo
    echo "${ORCH_NOTES}"
    echo
  fi
  echo "## Resume"
  echo
  echo "Receiving agent runs:"
  echo '```bash'
  echo "cd \"$REPO_ROOT\""
  echo "bash ~/.claude/skills/orchestrate-handoff/scripts/resume.sh"
  echo '```'
  echo
  echo "Generate paste-ready prompts with:"
  echo '```bash'
  echo "bash ~/.claude/skills/orchestrate-handoff/scripts/prepare-handoff.sh cursor"
  echo "bash ~/.claude/skills/orchestrate-handoff/scripts/prepare-handoff.sh codex"
  echo '```'
} > "$HANDOFF"

echo "[checkpoint] $HANDOFF"
