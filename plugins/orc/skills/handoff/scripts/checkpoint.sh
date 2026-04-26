#!/usr/bin/env bash
# orchestrate-handoff: checkpoint
# Writes .orc/state.json + .orc/HANDOFF.md.
#
# Auto-detection: if env vars are absent, derive from disk:
#   - plan_ref     → most recent .orc/plans/<slug>/plan.yaml mtime, fallback to <slug>.md
#   - wave         → previous state.json's wave field
#   - wave_status  → "running" if any cursor jobs alive, else "complete"/"idle"
#   - inflight     → live cursor-task-jobs PIDs from $TMPDIR/cursor-agent-jobs/
#   - next_action  → first undispatched PR in plan.yaml (best effort)
#   - routing      → previous state.json
#
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
PRIOR="$DIR/state.json"

# ── Auto-detect helpers ──────────────────────────────────────────────────────

_prior_field() {
  # Read field from prior state.json or empty.
  [ -f "$PRIOR" ] || { echo ""; return; }
  python3 -c "
import json, sys
try:
  d = json.load(open('$PRIOR'))
  v = d.get('$1', '')
  print(v if not isinstance(v, (list, dict)) else json.dumps(v))
except Exception:
  pass
" 2>/dev/null
}

_detect_plan_ref() {
  # Latest plan.yaml directory wins; fallback to legacy <slug>.md.
  local latest_dir
  latest_dir=$(ls -1dt "$DIR"/plans/*/plan.yaml 2>/dev/null | head -1)
  if [ -n "$latest_dir" ]; then
    dirname "$latest_dir" | sed "s|$REPO_ROOT/||"
    return
  fi
  local latest_md
  latest_md=$(ls -1t "$DIR"/plans/*.md 2>/dev/null | head -1)
  if [ -n "$latest_md" ]; then
    echo "$latest_md" | sed "s|$REPO_ROOT/||"
    return
  fi
  _prior_field plan_ref
}

_detect_inflight() {
  # cursor-task-jobs/*.pid files where the PID is still alive.
  local jobs_dir="${TMPDIR:-/tmp}/cursor-agent-jobs"
  [ -d "$jobs_dir" ] || { echo ""; return; }
  for pidfile in "$jobs_dir"/*.pid; do
    [ -f "$pidfile" ] || continue
    local pid; pid=$(cat "$pidfile" 2>/dev/null)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && \
      echo "cursor:$(basename "$pidfile" .pid):active"
  done
}

_detect_wave_status() {
  # If any inflight jobs, "running"; else "complete" if recent activity, else "idle".
  if [ -n "$1" ]; then echo "running"; return; fi
  local prior_state; prior_state=$(_prior_field wave_status)
  echo "${prior_state:-idle}"
}

# ── Resolve all fields (env override > auto-detect > prior > default) ────────

PLAN_REF="${ORCH_PLAN_REF:-$(_detect_plan_ref)}"
PLAN_REF="${PLAN_REF:-unknown}"

INFLIGHT_RAW="${ORCH_INFLIGHT_JOBS:-$(_detect_inflight)}"

WAVE="${ORCH_WAVE:-$(_prior_field wave)}"
WAVE="${WAVE:-0}"

WAVE_STATUS="${ORCH_WAVE_STATUS:-$(_detect_wave_status "$INFLIGHT_RAW")}"

NEXT_ACTION="${ORCH_NEXT_ACTION:-$(_prior_field next_action)}"

ROUTING_RAW="${ORCH_ROUTING_FILES:-$(_prior_field routing_files | python3 -c '
import json, sys
try:
  v = json.loads(sys.stdin.read() or "[]")
  print("\n".join(v) if isinstance(v, list) else "")
except Exception:
  pass
')}"

NOTES="${ORCH_NOTES:-}"

# ── Build JSON arrays ────────────────────────────────────────────────────────

INFLIGHT_JSON=$(printf '%s\n' "$INFLIGHT_RAW" | awk 'NF>0 {gsub(/"/,"\\\""); printf "%s\"%s\"", (NR>1?",":""), $0}')
INFLIGHT_JSON="[${INFLIGHT_JSON}]"

ROUTING_JSON=$(printf '%s\n' "$ROUTING_RAW" | awk 'NF>0 {gsub(/"/,"\\\""); printf "%s\"%s\"", (NR>1?",":""), $0}')
ROUTING_JSON="[${ROUTING_JSON}]"

esc_json() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }
NOTES_JSON=$(printf '%s' "$NOTES" | esc_json)
NEXT_ACTION_JSON=$(printf '%s' "$NEXT_ACTION" | esc_json)
PLAN_REF_JSON=$(printf '%s' "$PLAN_REF" | esc_json)
WAVE_STATUS_JSON=$(printf '%s' "$WAVE_STATUS" | esc_json)
GIT_HEAD=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "")
GIT_HEAD_JSON=$(printf '%s' "$GIT_HEAD" | esc_json)

cat > "$DIR/state.json" <<EOF
{
  "version": 1,
  "checkpointed_at": "$NOW",
  "last_activity_at": "$NOW",
  "repo_root": "$REPO_ROOT",
  "git_head": $GIT_HEAD_JSON,
  "plan_ref": $PLAN_REF_JSON,
  "wave": ${WAVE},
  "wave_status": $WAVE_STATUS_JSON,
  "inflight_jobs": $INFLIGHT_JSON,
  "routing_files": $ROUTING_JSON,
  "next_action": $NEXT_ACTION_JSON,
  "notes": $NOTES_JSON,
  "tasks_file": "$TASKS_JSON"
}
EOF

# ── Render HANDOFF.md ────────────────────────────────────────────────────────

HANDOFF="$DIR/HANDOFF.md"
{
  echo "# Orchestration Handoff"
  echo
  echo "**Checkpointed:** $NOW"
  echo "**Repo:** \`$REPO_ROOT\`"
  echo "**Git HEAD:** \`$GIT_HEAD\`"
  echo "**Plan:** $PLAN_REF"
  echo "**Wave:** $WAVE ($WAVE_STATUS)"
  echo
  echo "## Next action"
  echo
  echo "${NEXT_ACTION:-_(none recorded)_}"
  echo
  if [ -n "$INFLIGHT_RAW" ]; then
    echo "## In-flight jobs"
    echo
    echo '```'
    printf '%s\n' "$INFLIGHT_RAW" | awk 'NF>0'
    echo '```'
    echo
  fi
  if [ -n "$ROUTING_RAW" ]; then
    echo "## Routing context (read these first)"
    echo
    printf '%s\n' "$ROUTING_RAW" | awk 'NF>0 {print "- `" $0 "`"}'
    echo
  fi
  if [ -n "$NOTES" ]; then
    echo "## Notes"
    echo
    echo "$NOTES"
    echo
  fi
  echo "## Resume"
  echo
  echo "Receiving agent runs:"
  echo '```bash'
  echo "cd \"$REPO_ROOT\""
  echo "bash ~/.claude/plugins/marketplaces/athan-dial-skills/plugins/orc/skills/handoff/scripts/resume.sh"
  echo '```'
  echo
  echo "Generate paste-ready prompts with:"
  echo '```bash'
  echo "bash ~/.claude/plugins/marketplaces/athan-dial-skills/plugins/orc/skills/handoff/scripts/prepare-handoff.sh cursor"
  echo "bash ~/.claude/plugins/marketplaces/athan-dial-skills/plugins/orc/skills/handoff/scripts/prepare-handoff.sh codex"
  echo '```'
} > "$HANDOFF"

echo "[checkpoint] $HANDOFF (plan=$PLAN_REF wave=$WAVE/$WAVE_STATUS inflight=$(echo "$INFLIGHT_RAW" | awk 'NF>0' | wc -l | tr -d ' '))"
