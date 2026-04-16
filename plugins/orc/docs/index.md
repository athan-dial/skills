---
title: "orc"
description: "Multi-agent orchestration for Claude Code — wave-based parallel dispatch across Codex, Cursor, and Claude subagents."
plugin: "orc"
weight: 10
---

`orc` is a lightweight orchestration system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that manages the full dev session lifecycle: capture ideas, scope work, dispatch to parallel agents, run autonomous optimization loops, and hand off cleanly between sessions.

## Install

```bash
claude plugin install athan-dial/skills:orc
```

This installs seven `/orc:*` slash commands plus the underlying skills. Start a new Claude Code session and type `/orc:` to tab-complete.

## What's here

- **[Quickstart](quickstart/)** — paste-ready 5-minute walkthrough from cold start through your first orchestration.
- **[Commands](commands/)** — auto-generated reference for every `/orc:*` slash command.
- **[Architecture](architecture/)** — the wave-based parallel dispatch model, `.orc/state.json`, and how Claude / Cursor / Codex routing works.
- **[Changelog](changelog/)** — release history and semver policy.

## Why it exists

Most Claude Code sessions die at the boundaries: ideas captured mid-flow get lost, complex work gets serialized when it could fan out, and crash recovery means re-explaining everything. `orc` makes those boundaries cheap — `backlog` for capture, `orchestrate` for fan-out, `handoff` and `recap` for resumption.

## Source

Plugin source lives in the [athan-dial/skills](https://github.com/athan-dial/skills/tree/main/plugins/orc) monorepo. Issues and PRs welcome there.
