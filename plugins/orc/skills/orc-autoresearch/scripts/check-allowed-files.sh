#!/usr/bin/env bash
# Verify that the last commit only touched files in the allowed list.
# Usage: check-allowed-files.sh <slug>
# Exit 0 = clean, Exit 1 = violation (prints offending files)
set -euo pipefail

SLUG="${1:?Usage: check-allowed-files.sh <slug>}"
ALLOWED_FILE="var/autoresearch/${SLUG}/allowed_files.txt"

if [ ! -f "$ALLOWED_FILE" ]; then
  echo "ERROR: ${ALLOWED_FILE} not found"
  exit 1
fi

# Get files changed in last commit
CHANGED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || git diff --name-only HEAD)

VIOLATIONS=""
while IFS= read -r file; do
  [ -z "$file" ] && continue
  MATCH=0
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    # Support glob patterns (e.g., "src/**/*.py")
    # and exact paths
    case "$file" in
      $pattern) MATCH=1; break ;;
    esac
  done < "$ALLOWED_FILE"
  if [ "$MATCH" -eq 0 ]; then
    VIOLATIONS="${VIOLATIONS}${file}\n"
  fi
done <<< "$CHANGED"

if [ -n "$VIOLATIONS" ]; then
  echo "SCOPE VIOLATION: These files are outside the allowed mutable scope:"
  echo -e "$VIOLATIONS"
  exit 1
fi

echo "OK: All changed files within allowed scope"
exit 0
