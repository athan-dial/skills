#!/usr/bin/env bash
# tripwire.sh — proactive handoff trigger.
#
# Call after every N tool calls / wave completions. Decides whether to
# proactively run prepare-handoff.sh because we're "deep enough into a session"
# that a context exhaustion is plausible. Output: either silent (continue) or
# a one-line warning + paths to the paste-ready resume prompts.
#
# Heuristic (no real % API exposed):
#   - Count cursor-task-jobs lifetime PIDs in $TMPDIR/cursor-agent-jobs/
#   - Count git commits since session start (from .orc/state.json's session_started_at)
#   - If either exceeds threshold, suggest handoff prep
#
# Defaults:
#   ORC_TRIPWIRE_JOBS=15      → fire after 15 cursor jobs in this session
#   ORC_TRIPWIRE_COMMITS=20   → fire after 20 commits in this session
#   ORC_TRIPWIRE_HOURS=3      → fire after 3h elapsed since session start
#
# Always exits 0 (advisory only). Designed to be called liberally from
# dispatch's per-wave loop.

set -u

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE="$REPO_ROOT/.orc/state.json"
[ -f "$STATE" ] || exit 0

JOBS_DIR="${TMPDIR:-/tmp}/cursor-agent-jobs"
JOBS_THRESHOLD="${ORC_TRIPWIRE_JOBS:-15}"
COMMITS_THRESHOLD="${ORC_TRIPWIRE_COMMITS:-20}"
HOURS_THRESHOLD="${ORC_TRIPWIRE_HOURS:-3}"

# Count cursor jobs ever started (lifetime cumulative — proxy for "session activity")
n_jobs=0
if [ -d "$JOBS_DIR" ]; then
  n_jobs=$(find "$JOBS_DIR" -maxdepth 1 -name "*.pid" -mmin -180 2>/dev/null | wc -l | tr -d ' ')
fi

# Count commits in last 3 hours
n_commits=$(git -C "$REPO_ROOT" log --since='3 hours ago' --oneline 2>/dev/null | wc -l | tr -d ' ')

# Hours since first activity recorded in state
hours_elapsed=0
session_start=$(python3 -c "
import json
try:
  d = json.load(open('$STATE'))
  print(d.get('session_started_at') or d.get('checkpointed_at',''))
except Exception:
  pass
" 2>/dev/null)
if [ -n "$session_start" ]; then
  hours_elapsed=$(python3 -c "
from datetime import datetime, timezone
s = '$session_start'.rstrip('Z')
try:
  d = datetime.fromisoformat(s).replace(tzinfo=timezone.utc)
  delta = datetime.now(timezone.utc) - d
  print(int(delta.total_seconds() // 3600))
except Exception:
  print(0)
")
fi

trip=""
[ "$n_jobs"        -ge "$JOBS_THRESHOLD" ]    && trip="$trip jobs=$n_jobs/$JOBS_THRESHOLD"
[ "$n_commits"     -ge "$COMMITS_THRESHOLD" ] && trip="$trip commits=$n_commits/$COMMITS_THRESHOLD"
[ "$hours_elapsed" -ge "$HOURS_THRESHOLD" ]   && trip="$trip hours=$hours_elapsed/$HOURS_THRESHOLD"

if [ -n "$trip" ]; then
  echo "[tripwire] context-load signal — consider proactive handoff:$trip"
  echo "  bash ~/.claude/plugins/cache/athan-dial-skills/orc/0.6.0/skills/handoff/scripts/checkpoint.sh"
  echo "  bash ~/.claude/plugins/cache/athan-dial-skills/orc/0.6.0/skills/handoff/scripts/prepare-handoff.sh cursor"
fi

exit 0
