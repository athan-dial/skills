#!/usr/bin/env bash
# list-backlog.sh — framed Unicode dashboard for .orc/backlog/BACKLOG.jsonl.
# Single foreground call; harness streams stdout. Zero model tokens.
#
# Usage:
#   bash list-backlog.sh [--all] [--archived] [--compact] [--root PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="open"
COMPACT=""
ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)      MODE="all";      shift ;;
    --archived) MODE="archived"; shift ;;
    --compact)  COMPACT="1";     shift ;;
    --root)     ROOT="$2";       shift 2 ;;
    -h|--help)  sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Auto-detect .orc/backlog from CWD upward
if [[ -z "$ROOT" ]]; then
  d="$PWD"
  while [[ "$d" != "/" ]]; do
    if [[ -d "$d/.orc/backlog" ]]; then ROOT="$d/.orc/backlog"; break; fi
    d="$(dirname "$d")"
  done
fi
[[ -z "$ROOT" ]] && ROOT="$PWD/.orc/backlog"

WIDTH="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"

MODE="$MODE" COMPACT="$COMPACT" ROOT="$ROOT" WIDTH="$WIDTH" \
  python3 "$SCRIPT_DIR/_render_backlog.py"
