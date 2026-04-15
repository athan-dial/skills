# Agent Routing Guide

Two goals: (1) pick the right agent for each task, (2) maximize wave throughput.

## Role Separation

**Claude (orchestrator)** stays free for coordination, review, and decisions. Never dispatch Claude as a worker for tasks Codex/Cursor can handle. Claude's job is to decompose, dispatch, poll, review, and advance — not to do the coding work itself.

**Codex/Cursor** are the coding workers. Both read the full repo. The difference is model strength and concurrency:
- **Codex** uses a stronger model (GPT-5.4/o3) — better at multi-file reasoning, complex implementations
- **Cursor** uses a faster model — better for focused, self-contained edits

**Claude subagent** is for tasks only Claude can do: MCP access (Slack, Jira, Confluence, web) or analysis requiring orchestrator-level reasoning.

## Codex

Best for complex, multi-file code generation. Use when:
- Creating new files (models, views, components, tests)
- Multi-function implementations requiring cross-file coordination
- Large refactors spanning multiple functions
- >100 lines of new/changed code
- Tasks needing deep reasoning about architecture or patterns

**Parallelism:** Multiple Codex jobs can run concurrently — each dispatch returns a unique job ID tracked by the companion. Run up to 3 in parallel; the companion's `--all --json` status endpoint shows all running jobs simultaneously.

## Cursor

Best for fast, focused edits. Both Cursor and Codex read the full repo, but Cursor is faster for self-contained work. Use when:
- Single-file modifications
- Config file changes
- Small migrations or schema updates
- Adding/removing imports
- Renaming, moving, or deleting code
- <100 lines of change

**Limitation:** Max 3 parallel tasks.

## Claude Direct

No dispatch overhead. Use when:
- Reading files to verify state
- Running shell commands (make, test, lint)
- Checking file existence
- Running makemigrations or similar generators
- Any operation that takes <10 seconds

## Claude Subagent

Reserve for tasks that require MCP access or orchestrator-level reasoning. Use when:
- Slack messaging or search
- Jira/Confluence operations
- Outlook calendar/email
- Web search or fetch
- Analysis tasks needing synthesis across multiple sources

Use `isolation="worktree"` when the subagent modifies files to prevent conflicts.

**Making Claude subagents pollable:** Wrap the Agent call in a background Bash that writes progress to a sentinel file, then use `claude-bg` agent type in poll-wave.sh:
```bash
# sentinel path: $TMPDIR/claude-bg-<job_id>.status
echo "running: searching Confluence" > "$TMPDIR/claude-bg-slack-search.status"
# ... Agent call ...
echo "done" > "$TMPDIR/claude-bg-slack-search.status"
```

## Routing Decision Tree

```
Is it read-only or a shell command?
  → Yes: Claude direct

Does it need MCP (Slack, Jira, Confluence, web)?
  → Yes: Claude subagent

Is it a single-file edit or <100 LOC change?
  → Yes: Cursor

Is it multi-file, new creation, or >100 LOC?
  → Yes: Codex

Ambiguous?
  → Default to Cursor (faster startup, easier to retry)
```

## Scheduling for Throughput

All three agent types support parallel execution. The goal is maximum concurrency across all agents simultaneously — not serializing through any single agent type.

1. **Dispatch all independent tasks at once.** If a wave has 5 tasks with no dependencies, dispatch all 5 simultaneously across Codex + Cursor + Claude subagents.
2. **Use all agent types in parallel within a wave.** A wave can have 2 Codex jobs, 3 Cursor jobs, and 2 Claude subagents running simultaneously.
3. **Only queue when over the per-agent cap.** Excess tasks wait for a slot to open, not for a different wave.
4. **Front-load the longest-running tasks.** Start heavy multi-file Codex jobs first within a wave so they run while faster Cursor/Claude tasks finish and free up review cycles.

## Concurrency Rules

| Agent | Max Parallel | Queue Strategy | Pollable |
|-------|-------------|----------------|----------|
| Codex | 3 | Queue by dep order when >3 | Yes (JSON status API) |
| Cursor | 3 | Fill slots, queue overflow | Yes (PID + log tail) |
| Claude direct | Unlimited | Run immediately | N/A (inline) |
| Claude subagent | 3-5 | Use `run_in_background` for independence | Yes via `claude-bg` sentinel |
