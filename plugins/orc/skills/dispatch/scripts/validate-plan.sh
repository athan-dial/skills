#!/usr/bin/env bash
# validate-plan.sh — assert orc-plan/1 schema + invariants on a plan directory.
#
# Usage:  validate-plan.sh <path-to-plan-dir>
# Exit 0 + "PLAN OK" → safe to dispatch.
# Exit non-zero + specific errors → refuse to dispatch.

set -euo pipefail

PLAN_DIR="${1:?path to plan dir required (e.g. .orc/plans/<slug>)}"
PLAN_YAML="$PLAN_DIR/plan.yaml"

[ -f "$PLAN_YAML" ] || { echo "ERROR: $PLAN_YAML not found"; exit 1; }

# Use embedded Python to validate (PyYAML ships with most envs; fall back to ruamel/json if needed).
python3 - "$PLAN_DIR" "$PLAN_YAML" <<'PYEOF'
import os, re, sys, json
plan_dir, plan_yaml = sys.argv[1], sys.argv[2]
errors = []

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML not installed (pip install pyyaml).", file=sys.stderr); sys.exit(2)

try:
    with open(plan_yaml) as f:
        plan = yaml.safe_load(f)
except yaml.YAMLError as e:
    print(f"ERROR: plan.yaml parse error: {e}", file=sys.stderr); sys.exit(2)

def err(msg): errors.append(msg)

if not isinstance(plan, dict):
    err("plan.yaml root must be a mapping")
    print("\n".join(errors), file=sys.stderr); sys.exit(1)

if plan.get("format_version") != "orc-plan/1":
    err(f"format_version must be 'orc-plan/1', got {plan.get('format_version')!r}")

slug = plan.get("slug", "")
if not re.match(r"^[a-z][a-z0-9-]{0,39}$", slug):
    err(f"slug must match ^[a-z][a-z0-9-]{{0,39}}$, got {slug!r}")

if not plan.get("title"):
    err("title is required")

guard = plan.get("guard") or {}
if not isinstance(guard, dict) or not any(guard.get(k) for k in ("python","frontend","custom")):
    err("guard must contain at least one of: python, frontend, custom")

waves = plan.get("waves") or []
if not isinstance(waves, list) or not waves:
    err("waves must be a non-empty list")

# Track invariants across the plan
all_wt = []                  # cursor_wt across all tracks
all_pr_ids = []              # PR ids across all PRs
prompt_paths = []            # all prompt files referenced

def collect_pr(pr, wave_idx, track_id=None):
    pr_id = pr.get("id", "")
    if not pr_id: err(f"wave {wave_idx} {track_id or ''}: PR missing id")
    all_pr_ids.append(pr_id)

    prompt = pr.get("prompt", "")
    if not prompt:
        err(f"PR {pr_id}: prompt path required")
    else:
        full = os.path.join(plan_dir, prompt)
        if not os.path.isfile(full):
            err(f"PR {pr_id}: prompt file not found: {prompt}")
        prompt_paths.append(prompt)

    expected = pr.get("expected_files") or []
    if not isinstance(expected, list) or not expected:
        err(f"PR {pr_id}: expected_files must be a non-empty list")

    agent = pr.get("agent", "")
    if agent not in ("cursor","codex","claude-direct","claude-subagent"):
        err(f"PR {pr_id}: agent must be one of cursor/codex/claude-direct/claude-subagent")

for w_idx, wave in enumerate(waves):
    if not isinstance(wave, dict):
        err(f"wave {w_idx}: must be mapping"); continue

    serial = wave.get("serial", False)
    if "prs" in wave:
        for pr in wave["prs"]:
            collect_pr(pr, w_idx)
    if "tracks" in wave:
        # Per-wave file × PR collision detection
        wave_file_owners = {}  # path → track_id
        for track in wave["tracks"]:
            tid = track.get("id","")
            wt  = track.get("cursor_wt","")
            if not tid: err(f"wave {w_idx}: track missing id")
            if not wt:  err(f"wave {w_idx}/{tid}: cursor_wt required")
            else: all_wt.append(wt)
            for pr in track.get("prs") or []:
                collect_pr(pr, w_idx, tid)
                for f in pr.get("expected_files") or []:
                    prev = wave_file_owners.get(f)
                    if prev and prev != tid:
                        err(f"wave {w_idx}: file {f!r} claimed by both track {prev!r} and {tid!r} — extract to wave-0 or merge")
                    wave_file_owners[f] = tid

# Uniqueness checks
def dups(seq):
    seen = set(); out = []
    for x in seq:
        if x in seen: out.append(x)
        seen.add(x)
    return out

for d in dups(all_wt):       err(f"duplicate cursor_wt: {d!r}")
for d in dups(all_pr_ids):   err(f"duplicate PR id: {d!r}")

if errors:
    print("PLAN INVALID:", file=sys.stderr)
    for e in errors: print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

# Summary
total_prs = len(all_pr_ids)
total_tracks = len(all_wt)
print(f"PLAN OK: {plan['slug']!r} — {len(waves)} waves, {total_tracks} parallel tracks, {total_prs} PRs total")
PYEOF
