#!/usr/bin/env bash
# render-status.sh — single-pane view of orc system state.
# Zero model tokens; harness streams stdout.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Auto-detect repo root: walk up until we find .orc/ or .git/
if [[ -z "$ROOT" ]]; then
  d="$PWD"
  while [[ "$d" != "/" ]]; do
    if [[ -d "$d/.orc" ]] || [[ -d "$d/.git" ]]; then ROOT="$d"; break; fi
    d="$(dirname "$d")"
  done
fi
[[ -z "$ROOT" ]] && ROOT="$PWD"

WIDTH="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"

ROOT="$ROOT" WIDTH="$WIDTH" python3 "$SCRIPT_DIR/_render_status.py"
