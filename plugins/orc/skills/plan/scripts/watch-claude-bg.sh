#!/usr/bin/env zsh
# watch-claude-bg.sh — Monitor sentinel files for claude-bg jobs.
# Designed to run under the Monitor tool: each status change emits one stdout line.
# Exits (and ends the Monitor) when all jobs reach a terminal state.
#
# Usage:
#   zsh watch-claude-bg.sh [--timeout SECS] JOB_ID [JOB_ID ...]
#
# Sentinel path: $TMPDIR/claude-bg-<job_id>.status
# Write "done", "completed", "finished", "failed", or "error" to the sentinel
# from your Agent/Bash call to report completion.

setopt pipefail

INTERVAL=10
TIMEOUT=1200
JOB_IDS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval) INTERVAL="$2"; shift 2 ;;
    --timeout)  TIMEOUT="$2";  shift 2 ;;
    *)          JOB_IDS+=("$1"); shift ;;
  esac
done

if [[ ${#JOB_IDS[@]} -eq 0 ]]; then
  echo "Usage: watch-claude-bg.sh [--timeout N] job_id ..."
  exit 1
fi

typeset -A LAST_STATUS

is_terminal() {
  case "$1" in
    done|completed|finished|failed|error|cancelled) return 0 ;;
    *) return 1 ;;
  esac
}

read_sentinel() {
  local job_id="$1"
  local path="${TMPDIR:-/tmp}/claude-bg-${job_id}.status"
  if [[ ! -f "$path" ]]; then
    echo "pending"
    return
  fi
  local content
  content=$(cat "$path" 2>/dev/null | tr '[:upper:]' '[:lower:]')
  if echo "$content" | grep -q "done\|completed\|finished"; then
    echo "done"
  elif echo "$content" | grep -q "failed\|error"; then
    echo "failed"
  else
    echo "running"
  fi
}

START=$SECONDS

for job_id in "${JOB_IDS[@]}"; do
  LAST_STATUS[$job_id]="pending"
done

echo "watching ${#JOB_IDS[@]} claude-bg jobs"

while true; do
  sleep "$INTERVAL"

  all_done=true
  for job_id in "${JOB_IDS[@]}"; do
    [[ "${LAST_STATUS[$job_id]}" == "done" || "${LAST_STATUS[$job_id]}" == "failed" ]] && continue

    status=$(read_sentinel "$job_id")
    if [[ "$status" != "${LAST_STATUS[$job_id]}" ]]; then
      echo "${job_id}: ${status}"
      LAST_STATUS[$job_id]="$status"
    fi

    is_terminal "$status" || all_done=false
  done

  if $all_done; then
    echo "all_done"
    exit 0
  fi

  elapsed=$(( SECONDS - START ))
  if (( elapsed >= TIMEOUT )); then
    echo "timeout"
    exit 1
  fi
done
