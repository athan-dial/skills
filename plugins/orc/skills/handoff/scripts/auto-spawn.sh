#!/usr/bin/env bash
# Shared auto-handoff body. Called by hook scripts when a trigger fires.
# 1. Find any active orchestration (state.json modified in last 60 min)
# 2. Refresh checkpoint
# 3. Build a codex-target prompt as the default (chooser overrides at fire-time)
# 4. Spawn a cmux split running handoff-chooser.sh in that repo

set -u

# Find recent orchestration state files. Search common code dirs to keep `find` cheap.
SEARCH_ROOTS=(
  "$HOME/Github"
  "$HOME/code"
  "$HOME/projects"
  "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
)
STATE_FILES=""
for root in "${SEARCH_ROOTS[@]}"; do
  [ -d "$root" ] || continue
  found=$(find "$root" -maxdepth 5 -path '*/.orchestrate/state.json' -mmin -60 2>/dev/null)
  [ -n "$found" ] && STATE_FILES="$STATE_FILES"$'\n'"$found"
done
STATE_FILES=$(echo "$STATE_FILES" | awk 'NF>0')
[ -z "$STATE_FILES" ] && exit 0   # no recent orchestration; nothing to do

CMUX="/Applications/cmux.app/Contents/Resources/bin/cmux"
[ -x "$CMUX" ] || { echo "[auto-handoff] cmux CLI not found at $CMUX" >&2; exit 0; }

while IFS= read -r STATE; do
  REPO=$(dirname "$(dirname "$STATE")")
  [ -d "$REPO" ] || continue

  # Refresh checkpoint with whatever state.json already has (env vars unset here, so script no-ops env fields but rewrites HANDOFF.md from the JSON).
  ( cd "$REPO" && bash ~/.claude/skills/orchestrate-handoff/scripts/checkpoint.sh ) >/dev/null 2>&1 || true

  # Build the resume prompt (codex-flavored; chooser can re-target)
  PROMPT=$( cd "$REPO" && bash ~/.claude/skills/orchestrate-handoff/scripts/prepare-handoff.sh codex 2>/dev/null )
  echo "$PROMPT" > "$REPO/.orchestrate/AUTO-RESUME.txt"

  # Spawn cmux split running the chooser
  CHOOSER="$HOME/.claude/skills/orchestrate-handoff/scripts/handoff-chooser.sh"
  "$CMUX" new-split right --command "bash '$CHOOSER' '$REPO'" >/dev/null 2>&1 \
    || "$CMUX" new-pane --type terminal --direction right --command "bash '$CHOOSER' '$REPO'" >/dev/null 2>&1

  echo "[auto-handoff] spawned chooser for $REPO" >&2
done <<< "$STATE_FILES"
