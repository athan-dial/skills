---
title: "Quickstart"
description: "Five-minute walkthrough from install to your first orchestrated run."
weight: 20
---

This walks you from a cold install to dispatching your first parallel multi-agent run. Assumes you already have the [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed.

## 1. Install the plugin

```bash
claude plugin install athan-dial/skills:orc
```

Start a new Claude Code session in any repo. Type `/orc:` and tab-complete — you should see seven commands.

## 2. Recap (or skip on first run)

```text
/orc:recap
```

On a fresh repo this is a no-op. In an established `orc`-using repo, it reads `.orc/state.json`, the backlog, and recent commits, and tells you exactly where the last session left off.

## 3. Capture an idea

Mid-conversation, when something occurs to you that you don't want to lose:

```text
/orc:backlog add Refactor the auth middleware to use the new session store
```

`orc` snapshots the current conversation context (relevant files, why-now reasoning, suggested first step) into `.orc/backlog/NNN-*.md`. Survives across sessions.

## 4. Scope a backlog item into a plan

```text
/orc:scope 001
```

Reads the backlog entry, explores the relevant code, asks 1–2 clarifying questions if needed, and emits a scoped plan file with concrete tasks, file paths, and an executor recommendation per task (Claude / Codex / Cursor).

## 5. Dispatch in parallel

```text
/orc:dispatch
```

Picks up the latest scoped plan, decomposes it into dependency-ordered waves, dispatches each wave's tasks in parallel to the chosen executors, polls for completion, reviews diffs, and advances. State persists to `.orc/state.json` so a crash or `/clear` doesn't lose progress.

## 6. (Optional) Hill-climb a metric

For tasks framed as "improve metric X":

```text
/orc:autoresearch increase test coverage from 62% to 80%
```

Runs the [Karpathy autoresearch loop](https://karpathy.ai/): observe misses, hypothesize a fix, dispatch the edit, evaluate against the locked metric, keep or revert via git. Stops on plateau.

## 7. Handoff before ending

```text
/orc:handoff
```

Persists state to disk with a human-readable summary. Next session's `/orc:recap` will pick it up.

## What to read next

- **[Architecture](../architecture/)** — how wave dispatch and executor routing actually work under the hood.
- **[Commands](../commands/)** — full reference for every flag and argument.
