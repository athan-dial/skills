#!/usr/bin/env bash
# state.sh — one-liner mutations to .orc/state.json. Cheap idempotent updates.
#
# Subcommands:
#   show                            print state.json (pretty)
#   set <key> <value>               set top-level key (string/number auto-detected)
#   set-json <key> <json-literal>   set top-level key with raw JSON
#   add-job <agent:id:label>        append to inflight_jobs[]
#   clear-jobs                      reset inflight_jobs to []
#   touch                           bump last_activity_at + git_head only
#   note <text>                     append to notes (preserves prior)
#
# Always exits 0 on noop (e.g. no .orc/state.json — silently skips).
# All mutations bump last_activity_at as a side effect.

set -u

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE="$REPO_ROOT/.orc/state.json"

if [ ! -f "$STATE" ]; then
  echo "[state] no .orc/state.json in $REPO_ROOT — run checkpoint.sh first" >&2
  exit 1
fi

cmd="${1:-}"
shift || true

case "$cmd" in
  show)
    cat "$STATE"
    ;;

  set)
    key="${1:?key required}"
    val="${2:?value required}"
    NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    python3 - "$STATE" "$key" "$val" "$NOW" <<'PYEOF'
import json, sys
state, key, val, now = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(state) as f: d = json.load(f)
# Type coerce
try:
    if val.lower() in ("true","false"): coerced = val.lower() == "true"
    else: coerced = int(val) if val.lstrip("-").isdigit() else float(val) if "." in val else val
except Exception: coerced = val
d[key] = coerced
d["last_activity_at"] = now
with open(state, "w") as f: json.dump(d, f, indent=2)
print(f"[state] {key} = {coerced!r}")
PYEOF
    ;;

  set-json)
    key="${1:?key required}"
    raw="${2:?json required}"
    NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    python3 - "$STATE" "$key" "$raw" "$NOW" <<'PYEOF'
import json, sys
state, key, raw, now = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(state) as f: d = json.load(f)
d[key] = json.loads(raw)
d["last_activity_at"] = now
with open(state, "w") as f: json.dump(d, f, indent=2)
print(f"[state] {key} updated")
PYEOF
    ;;

  add-job)
    job="${1:?agent:id:label required}"
    NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    python3 - "$STATE" "$job" "$NOW" <<'PYEOF'
import json, sys
state, job, now = sys.argv[1], sys.argv[2], sys.argv[3]
with open(state) as f: d = json.load(f)
jobs = d.setdefault("inflight_jobs", [])
if job not in jobs: jobs.append(job)
d["last_activity_at"] = now
with open(state, "w") as f: json.dump(d, f, indent=2)
print(f"[state] inflight += {job}")
PYEOF
    ;;

  clear-jobs)
    NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    python3 - "$STATE" "$NOW" <<'PYEOF'
import json, sys
state, now = sys.argv[1], sys.argv[2]
with open(state) as f: d = json.load(f)
d["inflight_jobs"] = []
d["last_activity_at"] = now
with open(state, "w") as f: json.dump(d, f, indent=2)
print("[state] inflight cleared")
PYEOF
    ;;

  touch)
    NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    GIT_HEAD=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "")
    python3 - "$STATE" "$NOW" "$GIT_HEAD" <<'PYEOF'
import json, sys
state, now, git_head = sys.argv[1], sys.argv[2], sys.argv[3]
with open(state) as f: d = json.load(f)
d["last_activity_at"] = now
if git_head: d["git_head"] = git_head
with open(state, "w") as f: json.dump(d, f, indent=2)
PYEOF
    echo "[state] touched"
    ;;

  note)
    text="${1:?note text required}"
    NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    python3 - "$STATE" "$text" "$NOW" <<'PYEOF'
import json, sys
state, text, now = sys.argv[1], sys.argv[2], sys.argv[3]
with open(state) as f: d = json.load(f)
prior = d.get("notes") or ""
d["notes"] = (prior + "\n" if prior else "") + f"[{now}] {text}"
d["last_activity_at"] = now
with open(state, "w") as f: json.dump(d, f, indent=2)
print(f"[state] note appended")
PYEOF
    ;;

  *)
    cat <<USAGE
Usage:
  state.sh show
  state.sh set <key> <value>
  state.sh set-json <key> <json>
  state.sh add-job <agent:id:label>
  state.sh clear-jobs
  state.sh touch
  state.sh note <text>
USAGE
    exit 1
    ;;
esac
