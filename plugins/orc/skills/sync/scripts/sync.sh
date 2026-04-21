#!/usr/bin/env bash
# orc:sync — TaskNotes-first sync to orc backlog cache, with optional Multica bridge triggers.
#
# Pull: TaskNotes (canonical) -> .orc/backlog/BACKLOG.jsonl (cache)
# Push: local captures (no tasknotes_id yet) -> TaskNotes (best-effort)
#
# Bridge triggers are edge-only: after meaningful create/complete batches.
set -euo pipefail

MODE="both"          # both | pull | push
PROJECT_SLUG=""
DRY_RUN="false"
NO_BRIDGE="false"

while [ $# -gt 0 ]; do
  case "$1" in
    --pull) MODE="pull"; shift ;;
    --push) MODE="push"; shift ;;
    --project) PROJECT_SLUG="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN="true"; shift ;;
    --no-bridge) NO_BRIDGE="true"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FALLBACK_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
REPO_ROOT="${ORC_REPO_ROOT:-}"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$FALLBACK_ROOT")"
fi
ORC_DIR="$REPO_ROOT/.orc"
BACKLOG_DIR="$ORC_DIR/backlog"
BACKLOG_JSONL="$BACKLOG_DIR/BACKLOG.jsonl"
STATE_JSON="$ORC_DIR/state.json"

mkdir -p "$BACKLOG_DIR"
[ -f "$BACKLOG_JSONL" ] || : > "$BACKLOG_JSONL"

if [ -z "$PROJECT_SLUG" ] && [ -f "$STATE_JSON" ]; then
  PROJECT_SLUG="$(python3 -c 'import json; import sys; p=json.load(open(sys.argv[1])); print((p.get("project_slug") or "").strip())' "$STATE_JSON" 2>/dev/null || true)"
fi

BRIDGE_TRIGGER="$(cd "$(dirname "$0")" && pwd)/bridge-trigger.sh"

pull() {
  local tmp out added removed
  tmp="$(mktemp)"
  out="$(mktemp)"

  # Fetch tasks and render desired cache JSONL via python (agent_tag+shaped recovered from frontmatter).
  curl -sf "http://localhost:8080/api/tasks?limit=200" >"$tmp"
  python3 - "$tmp" "$PROJECT_SLUG" >"$out" <<'PY'
import datetime as dt
import json, sys
from pathlib import Path

payload = json.load(open(sys.argv[1]))
project = (sys.argv[2] or "").strip()
data = payload.get("data") or {}
vault = data.get("vault") or {}
vault_root = vault.get("path") or ""
tasks = data.get("tasks") or []
allowed = {"claude","claude-run","claude-show","claude-mcp"}
terminal = {"done","cancelled","canceled","completed","closed"}

def parse_frontmatter(path: Path) -> dict:
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return {}
    if not text.startswith("---"):
        return {}
    parts = text.split("\n---", 2)
    if len(parts) < 2:
        return {}
    fm_text = parts[0].lstrip("-").strip()  # first block between --- ... ---
    # extremely small yaml-ish parser: key: value lines only
    fm = {}
    for line in fm_text.splitlines():
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        fm[k.strip()] = v.strip().strip('"').strip("'")
    return fm

now = dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00","Z")

items = []
for t in tasks:
    status = str(t.get("status","")).lower()
    if status in terminal:
        continue
    task_path = str(t.get("path","")).strip()
    if not task_path or task_path.startswith("100 Tasks/TaskNotes/Archive/"):
        continue
    fm = parse_frontmatter(Path(vault_root) / task_path) if vault_root else {}
    agent_tag = (str(t.get("agent_tag","")).strip() or str(fm.get("agent_tag","")).strip())
    shaped = str(fm.get("shaped","")).lower() in {"true","yes","1"}
    if agent_tag not in allowed or not shaped:
        continue
    project_slug = str(fm.get("project_slug","")).strip()
    if project and project_slug and project_slug != project:
        continue

    # cache fields
    items.append({
        "tasknotes_id": str(t.get("id") or task_path),
        "title": str(t.get("title","")).strip(),
        "priority": "p1" if str(t.get("priority","")).lower()=="high" else "p2",
        "agent_tag": agent_tag,
        "task_type": str(fm.get("task_type","")).strip() or None,
        "admin_state": str(fm.get("admin_state","")).strip() or None,
        "approval": str(fm.get("approval","")).strip() or None,
        "worker": str(fm.get("worker","")).strip() or None,
        "project_slug": project_slug or (project or None),
        "source": str(fm.get("source","")).strip() or "manual",
        "plan_slug": str(fm.get("plan_slug","")).strip() or None,
        "multica_id": None,
        "synced_at": now,
        "status": "open",
    })

items.sort(key=lambda x: (x.get("priority") or "p2", x.get("title") or ""))
for i, item in enumerate(items, start=1):
    item["id"] = f"{i:03d}"
    sys.stdout.write(json.dumps(item, ensure_ascii=False) + "\n")
PY

  # Compare old vs new by tasknotes_id
  added="$(python3 - "$BACKLOG_JSONL" "$out" <<'PY'
import json,sys
def ids(p):
    s=set()
    for line in open(p,encoding="utf-8"):
        line=line.strip()
        if not line: continue
        try: s.add(json.loads(line).get("tasknotes_id"))
        except Exception: pass
    return s
old=ids(sys.argv[1]); new=ids(sys.argv[2])
print(len([x for x in new-old if x]))
PY
)"
  removed="$(python3 - "$BACKLOG_JSONL" "$out" <<'PY'
import json,sys
def ids(p):
    s=set()
    for line in open(p,encoding="utf-8"):
        line=line.strip()
        if not line: continue
        try: s.add(json.loads(line).get("tasknotes_id"))
        except Exception: pass
    return s
old=ids(sys.argv[1]); new=ids(sys.argv[2])
print(len([x for x in old-new if x]))
PY
)"

  if [ "$DRY_RUN" = "true" ]; then
    echo "[sync] DRY-RUN pull: would write cache ($added added, $removed removed) to $BACKLOG_JSONL" >&2
  else
    mv "$out" "$BACKLOG_JSONL"
    echo "[sync] pull: wrote cache ($added added, $removed removed) to $BACKLOG_JSONL" >&2
  fi

  rm -f "$tmp" "$out" || true

  if [ "$NO_BRIDGE" != "true" ] && [ "$DRY_RUN" != "true" ] && { [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; }; then
    bash "$BRIDGE_TRIGGER" --forward || true
  fi
}

push() {
  local tmp_out tmp_cnt created
  tmp_out="$(mktemp)"
  tmp_cnt="$(mktemp)"

  python3 - "$BACKLOG_JSONL" "$PROJECT_SLUG" "$DRY_RUN" >"$tmp_out" 2>"$tmp_cnt" <<'PY'
import datetime as dt
import json, os, subprocess, sys, urllib.request

backlog_path = sys.argv[1]
project_slug = (sys.argv[2] or "").strip()
dry_run = (sys.argv[3] == "true")

def post_task(title: str, agent_tag: str) -> dict:
    data = json.dumps({"title": title, "status": "todo", "agent_tag": agent_tag}).encode("utf-8")
    req = urllib.request.Request(
        "http://localhost:8080/api/tasks",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.load(resp)

def obsidian_set(path: str, name: str, value: str) -> None:
    if not path:
        return
    # best-effort
    subprocess.run(
        ["obsidian", "vault=2B-new", "property:set", f"path={path}", f"name={name}", f"value={value}"],
        capture_output=True,
        text=True,
    )

now = dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00","Z")
created = 0
lines_out = []

for line in open(backlog_path, encoding="utf-8"):
    raw = line.strip()
    if not raw:
        continue
    try:
        obj = json.loads(raw)
    except Exception:
        lines_out.append(raw)
        continue

    # Only push items missing a usable tasknotes_id
    tid = str(obj.get("tasknotes_id") or "").strip()
    if tid:
        lines_out.append(json.dumps(obj, ensure_ascii=False))
        continue

    # Respect project scope if present
    obj_project = str(obj.get("project_slug") or "").strip()
    if project_slug and obj_project and obj_project != project_slug:
        lines_out.append(json.dumps(obj, ensure_ascii=False))
        continue

    title = str(obj.get("title") or "").strip() or "orc capture"
    agent_tag = str(obj.get("agent_tag") or "").strip() or "claude-show"

    if dry_run:
        obj["tasknotes_id"] = "<dry-run>"
        obj["synced_at"] = now
        lines_out.append(json.dumps(obj, ensure_ascii=False))
        created += 1
        continue

    payload = post_task(title, agent_tag)
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, dict):
        lines_out.append(json.dumps(obj, ensure_ascii=False))
        continue

    task_path = str(data.get("path") or "").strip()
    # TaskNotes id is path-based in this system; keep as path for join to Multica meta.
    obj["tasknotes_id"] = task_path
    obj["synced_at"] = now

    # Best-effort typed fields on the created TaskNotes note.
    obsidian_set(task_path, "task_type", str(obj.get("task_type") or "development_task"))
    obsidian_set(task_path, "admin_state", str(obj.get("admin_state") or "observed"))
    if obj_project:
        obsidian_set(task_path, "project_slug", obj_project)
    obsidian_set(task_path, "source", str(obj.get("source") or "orc_capture"))

    lines_out.append(json.dumps(obj, ensure_ascii=False))
    created += 1

for out in lines_out:
    sys.stdout.write(out + "\n")

print(created, file=sys.stderr, flush=True)
PY
  created="$(tr -d ' \n' <"$tmp_cnt" || true)"
  [ -n "$created" ] || created="0"

  if [ "$DRY_RUN" = "true" ]; then
    echo "[sync] DRY-RUN push: would create $created TaskNotes task(s) (backfilled missing tasknotes_id)" >&2
  else
    mv "$tmp_out" "$BACKLOG_JSONL"
    echo "[sync] push: created $created TaskNotes task(s) (backfilled missing tasknotes_id)" >&2
  fi

  rm -f "$tmp_out" "$tmp_cnt" || true

  if [ "$NO_BRIDGE" != "true" ] && [ "$DRY_RUN" != "true" ] && [ "${created:-0}" -gt 0 ]; then
    bash "$BRIDGE_TRIGGER" --forward || true
  fi
}

case "$MODE" in
  pull) pull ;;
  push) push ;;
  both) pull; push ;;
esac

