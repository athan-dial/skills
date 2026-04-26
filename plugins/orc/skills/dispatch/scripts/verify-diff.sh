#!/usr/bin/env bash
# verify-diff.sh — assert a worktree's diff matches expected_files.
#
# Usage:
#   verify-diff.sh <worktree-path> <expected-file> [<expected-file> ...]
#
# Exit codes:
#   0  — every expected file shows up in the diff and no out-of-scope files were touched
#   1  — empty diff (worker reported success but didn't write)
#   2  — missing files (some expected files weren't modified)
#   3  — scope drift (files modified outside the expected list)
#
# Output is a human-readable summary plus a JSON verdict line on stdout for programmatic parsing.

set -euo pipefail

WT="${1:?worktree path required}"
shift
[ "$#" -ge 1 ] || { echo "ERROR: at least one expected file required" >&2; exit 4; }

EXPECTED=("$@")

# Use git -C to inspect the worktree without changing cwd.
[ -d "$WT/.git" ] || [ -f "$WT/.git" ] || { echo "ERROR: $WT is not a git worktree" >&2; exit 4; }

# Files actually changed (modified, added, deleted, untracked) in the worktree.
ACTUAL=$(git -C "$WT" diff --name-only HEAD 2>/dev/null; git -C "$WT" ls-files --others --exclude-standard 2>/dev/null)
ACTUAL=$(echo "$ACTUAL" | sort -u | sed '/^$/d')

# Pass expected list as JSON via env to avoid bash→python quoting hell.
EXPECTED_JSON=$(printf '%s\n' "${EXPECTED[@]}" | python3 -c 'import json,sys;print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')

if [ -z "$ACTUAL" ]; then
  echo "verify-diff: EMPTY DIFF — worker may have reported success without writing"
  echo "{\"verdict\":\"empty\",\"missing\":${EXPECTED_JSON},\"drift\":[]}"
  exit 1
fi

# Compute set differences via Python (no jq dependency).
ACTUAL="$ACTUAL" EXPECTED_JSON="$EXPECTED_JSON" python3 <<'PYEOF'
import json, os, sys
actual = set(l for l in os.environ["ACTUAL"].splitlines() if l.strip())
expected = set(x.strip() for x in json.loads(os.environ["EXPECTED_JSON"]) if x.strip())

missing = sorted(expected - actual)
drift   = sorted(actual - expected)

if missing and drift:
    verdict, code = "missing+drift", 2
elif missing:
    verdict, code = "missing", 2
elif drift:
    verdict, code = "drift", 3
else:
    verdict, code = "ok", 0

print(f"verify-diff: verdict={verdict}")
if missing:
    print("  MISSING (expected, not changed):")
    for x in missing: print(f"    - {x}")
if drift:
    print("  DRIFT (changed, not expected):")
    for x in drift: print(f"    - {x}")
print(json.dumps({"verdict": verdict, "missing": missing, "drift": drift}))
sys.exit(code)
PYEOF
