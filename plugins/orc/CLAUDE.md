# orc

Lightweight orchestration system for Claude Code. Skills live in `skills/`, install via `bash install.sh`.

## Structure

```
skills/
  orc/              orc:plan — multi-agent execution (Cursor/Codex/Claude)
  orc-backlog/      orc:backlog — idea capture + triage + promote
  orc-autoresearch/ orc:autoresearch — autonomous metric optimization loops
  orc-scope/        orc:scope — shape idea into executable plan
  orc-status/       orc:status — single-pane dashboard
  orc-recap/        orc:recap — session-start briefing
  orc-handoff/      orc:handoff — crash recovery checkpoint
```

## Dev workflow

- Edit skills in `skills/`, then `bash install.sh` to deploy to `~/.claude/skills/`
- Test by starting a fresh `claude` session and invoking the skill
- Scripts in `skills/orc*/scripts/` must be kept executable

## Adding a new orc skill

1. Create `skills/orc-<name>/SKILL.md`
2. Set frontmatter `name: orc:<name>`
3. Include "Part of the orc system" in description for discoverability
4. `bash install.sh` and test in a fresh session
