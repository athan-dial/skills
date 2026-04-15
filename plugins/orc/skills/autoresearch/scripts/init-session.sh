#!/usr/bin/env bash
# Initialize an autoresearch session: branch + directory + allowed_files.txt
# Usage: init-session.sh <slug> [branch-name]
set -euo pipefail

SLUG="${1:?Usage: init-session.sh <slug> [branch-name]}"
BRANCH="${2:-autoresearch/${SLUG}}"
SESSION_DIR="var/autoresearch/${SLUG}"

# Create branch from current HEAD
git checkout -b "$BRANCH" 2>/dev/null || {
  echo "Branch $BRANCH already exists. Switching to it."
  git checkout "$BRANCH"
}

# Create session directory
mkdir -p "$SESSION_DIR"

# Initialize session.json
cat > "${SESSION_DIR}/session.json" <<EOF
{
  "slug": "${SLUG}",
  "branch": "${BRANCH}",
  "iteration": 0,
  "best_metric": null,
  "status": "init",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Create empty hypotheses log
touch "${SESSION_DIR}/hypotheses.jsonl"

# Placeholder for allowed files (caller fills this)
touch "${SESSION_DIR}/allowed_files.txt"

echo "Session initialized: ${SESSION_DIR}"
echo "Branch: ${BRANCH}"
