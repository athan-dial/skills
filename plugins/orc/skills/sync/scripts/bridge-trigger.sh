#!/usr/bin/env bash
# orc bridge trigger (vault-root).
# Runs `just sweep-forward` or `just sweep-reverse` from the TaskNotes vault root.
#
# Why: keep Multica live without cron. Called only on edge events.
#
# Usage:
#   bridge-trigger.sh --forward [--dry-run]
#   bridge-trigger.sh --reverse [--dry-run]
#   bridge-trigger.sh --forward --no-verbose
set -euo pipefail

MODE="forward"
DRY_RUN="false"
VERBOSE="true"

while [ $# -gt 0 ]; do
  case "$1" in
    --forward) MODE="forward"; shift ;;
    --reverse) MODE="reverse"; shift ;;
    --dry-run) DRY_RUN="true"; shift ;;
    --no-verbose) VERBOSE="false"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

VAULT_ROOT="${ORC_VAULT_ROOT:-}"
if [ -z "$VAULT_ROOT" ]; then
  # Discover from TaskNotes API payload (authoritative when API is up).
  VAULT_ROOT="$(curl -sf "http://localhost:8080/api/tasks?limit=1" | python3 -c 'import json,sys; p=json.load(sys.stdin); print(((p.get("data") or {}).get("vault") or {}).get("path",""))')"
fi

if [ -z "$VAULT_ROOT" ] || [ ! -d "$VAULT_ROOT" ]; then
  echo "[bridge-trigger] vault root not found (set ORC_VAULT_ROOT)" >&2
  exit 0
fi

cd "$VAULT_ROOT"

CMD=(just)
if [ "$MODE" = "forward" ]; then
  CMD+=(sweep-forward)
else
  CMD+=(sweep-reverse)
fi
if [ "$VERBOSE" = "false" ]; then
  # just recipes pass --verbose already; suppress our own logs only
  :
fi
if [ "$DRY_RUN" = "true" ]; then
  echo "[bridge-trigger] DRY-RUN: ${CMD[*]} (cwd=$VAULT_ROOT)" >&2
  exit 0
fi

echo "[bridge-trigger] ${CMD[*]} (cwd=$VAULT_ROOT)" >&2
${CMD[@]} >/dev/null

