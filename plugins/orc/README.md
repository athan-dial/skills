# orc

Lightweight orchestration system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Manages the full dev session lifecycle: capture ideas, scope work, dispatch to parallel agents, run autonomous optimization loops, and hand off cleanly between sessions.

## Install

```bash
claude plugin install athan-dial/skills:orc
```

This auto-discovers all 7 skills and installs them as a plugin with cross-agent support (Claude Code, Codex, Cursor, Gemini CLI, and others).

> **Note**: Requires GitHub access to the fl65inc org while the repo is private. Once public, anyone can install.

Start a new Claude Code session. Type `/orc:` and tab-complete to see all commands.

## Commands

| Command | What it does |
|---------|-------------|
| `orc:plan` | Break work into parallel tasks, dispatch to Cursor/Codex/Claude |
| `orc:backlog` | Capture ideas with rich context (`orc:add`, `orc:list`, `orc:pick`, `orc:triage`, `orc:drop`) |
| `orc:autoresearch` | Autonomous hill-climbing loop for any scalar metric |
| `orc:scope` | Shape a backlog item into an executable plan |
| `orc:status` | Single-pane dashboard of all orc activity |
| `orc:recap` | Cold-start briefing for new sessions |
| `orc:handoff` | Checkpoint state for crash recovery |

## Typical flow

```
orc:recap       "where did I leave off?"
orc:pick 001    load backlog item with full context
orc:scope 001   break into tasks, pick executors
orc:plan        dispatch and run autonomously
orc:autoresearch  loop on a sticky metric
orc:add         capture new ideas mid-session
orc:handoff     save state before ending
```

## How it works

**orc:plan** decomposes work into dependency-ordered waves and dispatches tasks to Cursor, Codex, or Claude subagents in parallel. It polls for completion, reviews diffs, and advances autonomously.

**orc:backlog** stores ideas as rich markdown files (why, context snapshot, files involved, suggested first step) with a JSONL index at `.orc/backlog/` in your repo. Context captured at idea-time survives across sessions.

**orc:autoresearch** implements Karpathy's autoresearch pattern: observe misses, hypothesize a fix, dispatch the edit, evaluate against a locked metric, keep or revert via git. Runs autonomously until the metric plateaus.

## Dependencies

- **Required**: Claude Code CLI
- **Optional**: Codex CLI (for `orc:plan` Codex dispatch), Cursor Agent CLI (for `orc:plan` Cursor dispatch). Falls back to Claude direct if neither is installed.

## Repo layout

```
skills/           Skill source (SKILL.md + scripts + references per skill)
tests/            Smoke tests for scripts
install.sh        Deploy to ~/.claude/skills/
uninstall.sh      Remove from ~/.claude/skills/
```

## Update

```bash
npx skills update orc
```

Or manually: `git pull && bash install.sh`

## Uninstall

```bash
npx skills remove orc orc-backlog orc-autoresearch orc-handoff orc-status orc-recap orc-scope
```

Or manually: `bash uninstall.sh`

## License

MIT
