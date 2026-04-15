---
title: "Architecture"
description: "How orc decomposes work into parallel waves and routes tasks across Claude, Cursor, and Codex."
weight: 30
---

`orc` is built around three ideas: **wave-based dispatch**, **persistent state on disk**, and **executor-agnostic task routing**. Together they let a single Claude Code session drive multiple parallel agents without losing track.

## Wave-based dispatch

A scoped plan is a list of tasks with dependencies. `/orc:orchestrate` topologically sorts them into **waves** — sets of tasks with no unsatisfied dependencies — and dispatches each wave's tasks in parallel.

```
Wave 1: [A, B, C]   ← all start simultaneously
                ↓ (wait for all to finish)
Wave 2: [D, E]      ← D depends on A,B; E depends on C
                ↓
Wave 3: [F]         ← F depends on D and E
```

Within a wave, tasks run concurrently. Across waves, `orc` blocks until every task in the prior wave reports completion (or failure, which short-circuits the run for review).

This is intentionally simpler than a true DAG scheduler — wave granularity is enough for typical 5–15 task plans and keeps the state machine human-readable.

## Persistent state: `.orc/`

Everything lives in `.orc/` at the repo root:

| Path | Purpose |
|---|---|
| `.orc/state.json` | Active orchestration state — current wave, task statuses, executor PIDs, started-at timestamps. Survives `/clear` and crashes. |
| `.orc/backlog/NNN-slug.md` | One file per backlog item, rich context captured at idea-time. |
| `.orc/backlog/index.jsonl` | Append-only index for fast listing. |
| `.orc/plans/NNN-slug.md` | Scoped plan files emitted by `/orc:scope`. |
| `.orc/handoff/HANDOFF.md` | Latest checkpoint summary, written by `/orc:handoff`, read by `/orc:recap`. |

State files are designed to be human-editable. If a task gets stuck, edit `state.json` directly and re-run `/orc:orchestrate` — it picks up where you left it.

## Executor routing

Each task in a scoped plan declares an `executor` field, one of:

- **`claude`** — dispatch as a Claude Code subagent in this session. Best for tasks that need the orchestrator's full context.
- **`codex`** — shell out to the [Codex CLI](https://github.com/openai/codex) running headless. Best for self-contained code transforms where Codex's repo-aware mode shines.
- **`cursor`** — shell out to the Cursor Agent CLI in headless mode. Best for tasks that benefit from Cursor's diff-review UX (which `orc` then ingests).

`/orc:scope` recommends an executor per task based on the task shape. If Codex or Cursor isn't installed, `orc` falls back to Claude — nothing breaks, you just lose the parallelism advantage of farming work to other agents.

## Why subagents over a single conversation

Claude Code's main session has a finite context window. Pushing every task's code reads, edits, and tool output through that one window means hitting auto-compact on long plans. By dispatching each task to a subagent (or external CLI), the orchestrator only sees the **task summary** plus any diff — keeping the main context lean enough to coordinate dozens of tasks across a session.

## The autoresearch loop

`/orc:autoresearch` is a different control structure: not a fan-out, but a tight observe → hypothesize → edit → evaluate → keep-or-revert loop. Inspired by Andrej Karpathy's autoresearch pattern, it runs autonomously against a locked scalar metric (test coverage, p99 latency, accuracy on a held-out set) until improvement plateaus or a step budget exhausts. Each accepted improvement is its own git commit, so revert is one-line.

## What orc deliberately doesn't do

- **No remote execution.** Everything runs on your machine. No Anthropic-hosted runner, no shared queue.
- **No fancy DAG.** Waves, not arbitrary graphs. Adequate for the workload, debuggable.
- **No GUI.** Status is a markdown table from `/orc:status`. State is files. Inspectable with `cat`.
