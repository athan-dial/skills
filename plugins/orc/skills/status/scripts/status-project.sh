#!/usr/bin/env bash
# status-project.sh — project-scoped status aggregator (TaskNotes + Multica + orc cache).
#
# Usage:
#   status-project.sh <project_slug>
#
# Prints a markdown block to stdout.
set -euo pipefail

PROJECT_SLUG="${1:-}"
if [ -z "$PROJECT_SLUG" ]; then
  echo "usage: $0 <project_slug>" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ORC_BACKLOG="$REPO_ROOT/.orc/backlog/BACKLOG.jsonl"
ORC_STATE="$REPO_ROOT/.orc/state.json"

VAULT_ROOT="$(curl -sf "http://localhost:8080/api/tasks?limit=1" | python3 -c 'import json,sys; p=json.load(sys.stdin); print(((p.get("data") or {}).get("vault") or {}).get("path",""))')"
TOOLS="$VAULT_ROOT/.tools"

PROJECT_ID="$(python3 - "$TOOLS" "$VAULT_ROOT" "$PROJECT_SLUG" <<'PY'
import sys
tools, vault_root, slug = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, tools)
from fm_utils import build_project_slug_to_multica_id  # type: ignore
m = build_project_slug_to_multica_id(vault_root)
print(m.get(slug, ""))
PY
)"

multica_counts() {
  local pid="$1"
  if [ -z "$pid" ]; then
    echo "no_project_id"
    return 0
  fi
  python3 - "$pid" <<'PY'
import json,subprocess,sys,collections
pid=sys.argv[1]
statuses=["backlog","todo","in_progress","done","blocked","failed"]
counts=collections.Counter()
for st in statuses:
  p=subprocess.run(["multica","issue","list","--project",pid,"--status",st,"--limit","500","--output","json"],capture_output=True,text=True)
  if p.returncode!=0: continue
  try:
    items=json.loads(p.stdout or "[]")
    if isinstance(items,list):
      counts[st]=len(items)
  except Exception:
    pass
print(json.dumps(counts))
PY
}

tasknotes_counts() {
  python3 - "$VAULT_ROOT" "$PROJECT_SLUG" <<'PY'
import json,sys,urllib.request
from pathlib import Path

vault_root=Path(sys.argv[1])
slug=sys.argv[2]
tasks_url="http://localhost:8080/api/tasks?offset=0&limit=2000"
payload=json.load(urllib.request.urlopen(tasks_url, timeout=15))
data=(payload.get("data") or {})
tasks=data.get("tasks") or []

def parse_fm(p: Path) -> dict:
    try: text=p.read_text(encoding="utf-8")
    except Exception: return {}
    if not text.startswith("---"): return {}
    end=text.find("\n---",3)
    if end==-1: return {}
    fm={}
    for line in text[3:end].splitlines():
        if ":" not in line: continue
        k,v=line.split(":",1)
        fm[k.strip()]=v.strip().strip('"').strip("'")
    return fm

counts={}
for t in tasks:
    path=t.get("path","")
    if not path: continue
    fm=parse_fm(vault_root / path)
    if (fm.get("project_slug","") or "").strip()!=slug:
        continue
    admin=(fm.get("admin_state","") or "").strip() or "(missing)"
    counts[admin]=counts.get(admin,0)+1
print(json.dumps(counts))
PY
}

orc_counts() {
  if [ ! -f "$ORC_BACKLOG" ]; then
    echo "{}"
    return 0
  fi
  python3 - "$ORC_BACKLOG" "$PROJECT_SLUG" <<'PY'
import json,sys
p=sys.argv[1]; slug=sys.argv[2]
counts={}
for line in open(p,encoding="utf-8"):
    line=line.strip()
    if not line: continue
    try: obj=json.loads(line)
    except Exception: continue
    if (obj.get("project_slug") or "").strip()!=slug:
        continue
    pr=obj.get("priority","p2")
    counts[pr]=counts.get(pr,0)+1
print(json.dumps(counts))
PY
}

MC_JSON="$(multica_counts "$PROJECT_ID")"
TN_JSON="$(tasknotes_counts)"
ORC_JSON="$(orc_counts)"

ACTIVE_PLAN=""
if [ -f "$ORC_STATE" ]; then
  ACTIVE_PLAN="$(python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); print(p.get("plan_ref",""))' "$ORC_STATE" 2>/dev/null || true)"
fi

cat <<EOF
**orc** · project: \`$PROJECT_SLUG\`

| Layer | Summary |
|---|---|
| Multica | project_id=\`$PROJECT_ID\` · counts=\`$MC_JSON\` |
| TaskNotes | admin_state counts=\`$TN_JSON\` |
| orc cache | priority counts=\`$ORC_JSON\` |
| Active plan | \`${ACTIVE_PLAN:-—}\` |
EOF

