#!/usr/bin/env bash
# cursor-task-iso.sh — parallel-safe cursor-agent dispatcher via per-job HOME isolation.
#
# Each invocation runs in its own throwaway HOME so concurrent jobs do not race on
# ~/.cursor/cli-config.json (the standard cursor-agent atomic-write race).
#
# Required env:
#   CURSOR_WT       — unique worktree name (per parallel job)
#
# Optional env:
#   CURSOR_WT_BASE  — branch to base the worktree on (default: main)
#   CURSOR_WORKSPACE — workspace directory (default: pwd)
#   CURSOR_MODEL    — model override (default: auto)
#
# Usage:
#   CURSOR_WT=track-a cursor-task-iso.sh "<prompt>"        # start job (background)
#   cursor-task-iso.sh --status <job-id>                   # check status
#   cursor-task-iso.sh --result <job-id>                   # full output
#   cursor-task-iso.sh --wt-path <wt-name>                 # print worktree absolute path
#
# Validated empirically: 8/8 parallel dispatches with zero ENOENT races vs ~13% with
# `agent -w` alone (see orc 0.6.0 changelog).

set -euo pipefail

JOB_DIR="${TMPDIR:-/tmp}/cursor-agent-jobs"
mkdir -p "$JOB_DIR"

# ── status ────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--status" ]]; then
  JOB_ID="${2:?Job ID required}"
  LOG="$JOB_DIR/$JOB_ID.log"
  PID_FILE="$JOB_DIR/$JOB_ID.pid"
  [[ -f "$LOG" ]] || { echo "Job not found: $JOB_ID"; exit 1; }
  PID=$(cat "$PID_FILE" 2>/dev/null || echo "")
  if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
    STATUS="running"
  else
    STATUS="done"
  fi
  echo "Job: $JOB_ID | $STATUS"
  exit 0
fi

# ── result ────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--result" ]]; then
  JOB_ID="${2:?Job ID required}"
  LOG="$JOB_DIR/$JOB_ID.log"
  [[ -f "$LOG" ]] || { echo "Job not found: $JOB_ID"; exit 1; }
  cat "$LOG"
  exit 0
fi

# ── wt-path ───────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--wt-path" ]]; then
  WT_NAME="${2:?Worktree name required}"
  REPO_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
  echo "$HOME/.cursor/worktrees/$REPO_NAME/$WT_NAME"
  exit 0
fi

# ── start ─────────────────────────────────────────────────────────────────────
WT_NAME="${CURSOR_WT:?CURSOR_WT env var required (unique worktree name per parallel job)}"
PROMPT="${1:?Prompt required}"
WORKSPACE="${CURSOR_WORKSPACE:-$(pwd)}"
BASE_BRANCH="${CURSOR_WT_BASE:-main}"
MODEL="${CURSOR_MODEL:-auto}"

JOB_ID="cursor-$(date +%s)-$(openssl rand -hex 3)"
LOG="$JOB_DIR/$JOB_ID.log"
PID_FILE="$JOB_DIR/$JOB_ID.pid"
ISO_HOME=$(mktemp -d -t "cursor-iso-${WT_NAME}-XXX")

# Seed the isolated HOME with the minimum cursor-agent needs:
#   - ~/.cursor/cli-config.json   (auth reference + permissions)
#   - ~/.cursor/agent-cli-state.json (CLI bookkeeping)
#   - ~/Library symlink           (macOS Keychain access path; required for token lookup)
#   - ~/.cursor/worktrees symlink (so `agent -w` worktrees live at the REAL persistent
#                                  ~/.cursor/worktrees/ — not in the throwaway iso HOME.
#                                  This is critical: without the symlink, the trap below
#                                  deletes the worktree alongside the iso HOME.)
mkdir -p "$ISO_HOME/.cursor"
mkdir -p "$HOME/.cursor/worktrees"
[ -f "$HOME/.cursor/cli-config.json" ]      && cp "$HOME/.cursor/cli-config.json"      "$ISO_HOME/.cursor/" || true
[ -f "$HOME/.cursor/agent-cli-state.json" ] && cp "$HOME/.cursor/agent-cli-state.json" "$ISO_HOME/.cursor/" || true
ln -s "$HOME/.cursor/worktrees" "$ISO_HOME/.cursor/worktrees"
ln -s "$HOME/Library"           "$ISO_HOME/Library"

# Spawn agent with isolated HOME. Trap cleans up the iso HOME after agent exits.
# Worker socket files inside .cursor sometimes block immediate rmdir; the || true
# in the trap is intentional.
nohup bash -c '
  trap "rm -rf '"'$ISO_HOME'"' 2>/dev/null || true" EXIT
  HOME='"$ISO_HOME"' agent \
    --print \
    --force \
    --trust \
    --sandbox disabled \
    --model '"$MODEL"' \
    --workspace '"$WORKSPACE"' \
    -w '"$WT_NAME"' \
    --worktree-base '"$BASE_BRANCH"' \
    '"$(printf '%q' "$PROMPT")"'
' > "$LOG" 2>&1 &

echo $! > "$PID_FILE"
echo "cursor-task started: $JOB_ID"
echo "Worktree: $WT_NAME"
echo "Iso HOME: $ISO_HOME"
echo "Log: $LOG"
