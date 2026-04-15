# orc

Lightweight orchestration system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Manages the full dev session lifecycle: capture ideas, scope work, dispatch to parallel agents, run autonomous optimization loops, and hand off cleanly between sessions.

**Full documentation:** <https://athandial.com/skills/orc/>

## Install

```bash
claude plugin install athan-dial/skills:orc
```

Start a new Claude Code session and type `/orc:` to tab-complete all seven commands.

## Commands

| Command | What it does |
|---------|-------------|
| `/orc:orchestrate` | Decompose work into dependency-ordered waves, dispatch to Cursor / Codex / Claude in parallel |
| `/orc:backlog` | Capture ideas with rich context; list, triage, pick, promote |
| `/orc:scope` | Shape a backlog item or freeform idea into a scoped plan |
| `/orc:autoresearch` | Karpathy-style autonomous hill-climbing loop on any scalar metric |
| `/orc:status` | Single-pane dashboard of all orc activity |
| `/orc:recap` | Cold-start briefing for new sessions |
| `/orc:handoff` | Checkpoint state for crash recovery |

See [the commands reference](https://athandial.com/skills/orc/commands/) for arguments and examples.

## Typical flow

```text
/orc:recap                    where did I leave off?
/orc:backlog add <idea>       capture mid-session
/orc:scope 001                shape into a plan
/orc:orchestrate              dispatch and run autonomously
/orc:autoresearch <metric>    loop on a sticky metric
/orc:handoff                  save state before ending
```

## Dependencies

- **Required:** Claude Code CLI
- **Optional:** [Codex CLI](https://github.com/openai/codex) and Cursor Agent CLI for parallel dispatch. `orc` falls back to Claude subagents if neither is installed.

## Repo layout

```
commands/         Slash command wrappers (/orc:*)
skills/           Skill source (SKILL.md + scripts per skill)
docs/             Source for athandial.com/skills/orc/
CHANGELOG.md      Release history + semver policy
```

## License

MIT
