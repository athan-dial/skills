#!/usr/bin/env bash
# Run guard + evaluator, then keep or revert.
# Usage: ratchet.sh <slug> <guard-command> <iteration-number>
# Outputs JSON to stdout: {"decision": "keep"|"revert", "metric": N, "prev_best": N, "delta": N}
set -euo pipefail

SLUG="${1:?Usage: ratchet.sh <slug> <guard-command> <iteration>}"
GUARD="${2:?Missing guard command}"
ITER="${3:?Missing iteration number}"
SESSION_DIR="var/autoresearch/${SLUG}"
EVAL_SCRIPT="${SESSION_DIR}/evaluate.sh"
ITER_FILE="${SESSION_DIR}/iteration-${ITER}.json"

# Read previous best from session.json
PREV_BEST=$(python3 -c "import json; d=json.load(open('${SESSION_DIR}/session.json')); print(d.get('best_metric') or 0)")

# Step 1: Run guard
if ! eval "$GUARD" > /dev/null 2>&1; then
  # Guard failed — revert
  git reset --hard HEAD~1 > /dev/null 2>&1
  cat <<EOF
{"decision": "revert", "reason": "guard_failed", "metric": null, "prev_best": ${PREV_BEST}, "delta": 0}
EOF
  exit 0
fi

# Step 2: Run evaluator
EVAL_OUTPUT=$(bash "$EVAL_SCRIPT" 2>/dev/null)
METRIC=$(echo "$EVAL_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['metric'])")

# Save full evaluator output
echo "$EVAL_OUTPUT" > "$ITER_FILE"

# Step 3: Compare
DELTA=$(python3 -c "print(round(${METRIC} - ${PREV_BEST}, 2))")
IMPROVED=$(python3 -c "print('true' if ${METRIC} > ${PREV_BEST} else 'false')")

if [ "$IMPROVED" = "true" ]; then
  # Keep — amend commit message with metric
  # (caller is responsible for the initial commit before calling ratchet)
  # Update session.json
  python3 -c "
import json
with open('${SESSION_DIR}/session.json', 'r') as f:
    d = json.load(f)
d['best_metric'] = ${METRIC}
d['iteration'] = ${ITER}
d['status'] = 'running'
with open('${SESSION_DIR}/session.json', 'w') as f:
    json.dump(d, f, indent=2)
"
  cat <<EOF
{"decision": "keep", "reason": "improved", "metric": ${METRIC}, "prev_best": ${PREV_BEST}, "delta": ${DELTA}}
EOF
else
  # Revert
  git reset --hard HEAD~1 > /dev/null 2>&1
  cat <<EOF
{"decision": "revert", "reason": "no_improvement", "metric": ${METRIC}, "prev_best": ${PREV_BEST}, "delta": ${DELTA}}
EOF
fi
