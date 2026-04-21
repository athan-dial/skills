#!/usr/bin/env bash
# Smoke test for orc command wiring and closed-loop invariants.
# No network calls, no TaskNotes writes — pure repo-local checks.
set -euo pipefail

P="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0

ok(){ echo "PASS: $*"; pass=$((pass+1)); }
bad(){ echo "FAIL: $*" >&2; fail=$((fail+1)); }

# Required commands exist
[ -f "$P/commands/dispatch.md" ] && ok "dispatch command exists" || bad "missing commands/dispatch.md"
[ -f "$P/commands/orchestrate.md" ] && ok "orchestrate alias exists" || bad "missing commands/orchestrate.md"
[ -f "$P/commands/sync.md" ] && ok "sync command exists" || bad "missing commands/sync.md"
[ -f "$P/commands/verify.md" ] && ok "verify command exists" || bad "missing commands/verify.md"

# Required skills exist
[ -f "$P/skills/dispatch/SKILL.md" ] && ok "dispatch skill exists" || bad "missing skills/dispatch/SKILL.md"
[ -f "$P/skills/sync/SKILL.md" ] && ok "sync skill exists" || bad "missing skills/sync/SKILL.md"
[ -f "$P/skills/verify/SKILL.md" ] && ok "verify skill exists" || bad "missing skills/verify/SKILL.md"

# Bridge trigger wrapper exists + executable
[ -x "$P/skills/sync/scripts/bridge-trigger.sh" ] && ok "bridge-trigger executable" || bad "missing bridge-trigger.sh"

# Project status aggregator exists + executable
[ -x "$P/skills/status/scripts/status-project.sh" ] && ok "status-project executable" || bad "missing status-project.sh"

# Docs should prefer /orc:dispatch. /orc:orchestrate is allowed only in:
# - commands/orchestrate.md (alias command)
# - skills/dispatch/SKILL.md (mentions legacy alias)
# - docs/reference/commands.md (documents alias)
# - docs/changelog.md (records rename)
if rg -n "/orc:orchestrate" "$P/docs" "$P/skills" "$P/commands" 2>/dev/null \
    | rg -v "/commands/orchestrate\\.md:" \
    | rg -v "/skills/dispatch/SKILL\\.md:" \
    | rg -v "/docs/reference/commands\\.md:" \
    | rg -v "/docs/changelog\\.md:" \
    >/dev/null 2>&1; then
  bad "found unexpected /orc:orchestrate references (docs should prefer dispatch)"
else
  ok "docs prefer /orc:dispatch (alias limited)"
fi

echo "---"
echo "smoke: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

