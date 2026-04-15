#!/usr/bin/env bash
# orchestrate-handoff: resume
# Receiving-side: re-attach to in-flight jobs, print status, echo next action.

set -u

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE="$REPO_ROOT/.orchestrate/state.json"
HANDOFF="$REPO_ROOT/.orchestrate/HANDOFF.md"
POLLER="$HOME/.claude/skills/orchestrate/scripts/poll-wave.sh"

if [ ! -f "$STATE" ]; then
  echo "ERROR: $STATE not found. Nothing to resume." >&2
  exit 1
fi

echo "=== Resuming orchestration ==="
echo
python3 <<PY
import json
s = json.load(open("$STATE"))
print(f"Repo:        {s.get('repo_root')}")
print(f"Plan:        {s.get('plan_ref')}")
print(f"Wave:        {s.get('wave')} ({s.get('wave_status')})")
print(f"Checkpoint:  {s.get('checkpointed_at')}")
print(f"Next action: {s.get('next_action') or '(none)'}")
print()
inflight = s.get('inflight_jobs', [])
print(f"In-flight jobs: {len(inflight)}")
for j in inflight: print(f"  - {j}")
print()
routing = s.get('routing_files', [])
if routing:
    print("Routing files to Read first:")
    for r in routing: print(f"  - {r}")
    print()
notes = s.get('notes', '').strip()
if notes:
    print("Notes from previous orchestrator:")
    print(notes)
    print()
PY

# Re-attach polling if jobs are listed
INFLIGHT=$(python3 -c "import json;print('\n'.join(json.load(open('$STATE')).get('inflight_jobs',[])))")
if [ -n "$INFLIGHT" ] && [ -x "$POLLER" ]; then
  echo "=== Re-attaching to in-flight jobs ==="
  echo "Run this to poll (foreground, streams to terminal):"
  echo
  echo "  zsh $POLLER \\"
  echo "$INFLIGHT" | awk 'NF>0 {print "    " $0 " \\"}' | sed '$ s/ \\$//'
  echo
fi

echo "=== Full handoff narrative: $HANDOFF ==="
