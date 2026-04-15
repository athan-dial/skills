#!/usr/bin/env bash
# list-backlog.sh — machine-readable backlog dump for piping/scripting.
# For human-facing views, Claude renders a markdown table per SKILL.md.
#
# Usage:
#   bash list-backlog.sh              # TSV: id<TAB>priority<TAB>title  (open items)
#   bash list-backlog.sh --all        # include archived
#   bash list-backlog.sh --archived   # archived only
#   bash list-backlog.sh --root PATH  # override backlog location

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="open"
ROOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)      MODE="all";      shift ;;
    --archived) MODE="archived"; shift ;;
    --root)     ROOT="$2";       shift 2 ;;
    -h|--help)  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$ROOT" ]]; then
  d="$PWD"
  while [[ "$d" != "/" ]]; do
    if [[ -d "$d/.orc/backlog" ]]; then ROOT="$d/.orc/backlog"; break; fi
    d="$(dirname "$d")"
  done
fi
[[ -z "$ROOT" ]] && ROOT="$PWD/.orc/backlog"

MODE="$MODE" ROOT="$ROOT" python3 "$SCRIPT_DIR/_list_compact.py"
