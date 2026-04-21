---
name: handoff
description: >
  Persist and resume orc:dispatch state to disk. ONLY invoke when: (1) the user explicitly says
  /orc:handoff, "checkpoint orchestration", "hand off", "resume orchestration",
  or "save orc state"; (2) CC displays an actual system usage-limit warning (not your
  guess that one is coming); (3) orc:orchestrate auto-calls checkpoint after a wave completes;
  (4) a fresh session needs to resume a prior orchestration via `resume`. Do NOT invoke because
  a session feels long, context feels large, or you think limits might be near. "Session is long"
  is never a trigger.
  Part of the orc system: orc:dispatch, orc:backlog, orc:autoresearch, orc:status, orc:recap, orc:scope, orc:handoff.
---

# Orchestrate Handoff

## STOP — Check triggers before proceeding

Do NOT run this skill unless one of these is true:
- The **user explicitly asked** for a checkpoint/handoff/resume
- CC displayed an **actual system usage-limit warning** in this turn
- `/orchestrate` is **auto-checkpointing after a completed wave**
- A **fresh session** is resuming a prior orchestration

If none apply, **exit this skill immediately**. "The session is long" or "context might be getting large" are NOT triggers. Trust the system to signal real limits.

---

Solves: when CC runs the `/orchestrate` orchestrator and hits a 5h usage limit mid-run, the in-flight task table, wave state, and dispatched job IDs are stranded inside CC's conversation. Workers (Codex/Cursor daemons) keep running on disk, but no agent can pick up the orchestrator role without losing them.

This skill writes orchestrator state to disk after every wave so any agent (CC, Cursor, Codex via codex-rescue) can re-attach.

## Three modes

| Mode | When | Who calls it |
|---|---|---|
| `checkpoint` | After every wave completes, or on demand | `/orchestrate` (auto) or user |
| `prepare-handoff [cursor\|codex]` | When usage limit is imminent | User (or CC reactively) |
| `resume` | Fresh session picking up an orchestration | Receiving agent (CC/Cursor/Codex) |

## State location

**Repo-local: `<repo-root>/.orc/`** — gitignored, follows the work, no global discovery step needed. Files:

- `state.json` — structured task table, wave history, in-flight jobs, routing context paths
- `HANDOFF.md` — human-readable narrative with paste-ready resume prompts for Cursor/Codex
- `tasks.json` — last TaskList snapshot (orchestrator pipes this in before checkpoint)

Add `.orc/` to `.gitignore` on first checkpoint if missing.

## Mode 1: `checkpoint`

**Invocation (from `/orchestrate` or user):**

```bash
bash ~/.claude/skills/orchestrate-handoff/scripts/checkpoint.sh
```

The script reads from environment variables. The orchestrator MUST export these before calling:

| Env var | Contents |
|---|---|
| `ORCH_PLAN_REF` | Path to plan file, or `freeform:<short hash>` if no file |
| `ORCH_WAVE` | Current wave number (integer) |
| `ORCH_WAVE_STATUS` | `dispatched` / `polling` / `complete` |
| `ORCH_INFLIGHT_JOBS` | Newline-separated `agent:job_id:label` triples (poll-wave.sh format). Empty if no jobs in flight. |
| `ORCH_ROUTING_FILES` | Newline-separated `.mex/context/*.md` paths loaded in Phase 0 |
| `ORCH_NEXT_ACTION` | One-line description of next step |
| `ORCH_NOTES` | Optional: open decisions, blockers, recent reroutes |

For task table: orchestrator can optionally write `.orc/tasks.json` (e.g., echoing TaskList output as JSON) before invoking the script. If absent, checkpoint still runs but state.json's task table will be empty.

**What the script does:**
1. Creates `.orc/` if missing, adds entry to repo `.gitignore`
2. Writes `state.json` from env vars + `tasks.json` (if present) + ISO timestamp
3. Renders `HANDOFF.md` with current state and paste-ready Cursor/Codex resume prompts
4. Echoes the path to `HANDOFF.md`

The script is idempotent and overwrites previous checkpoints (not append-only — the latest state is always authoritative).

**Where `/orchestrate` calls this:** at the end of Phase 2's per-wave loop, after the review step but before dispatching the next wave.

## Mode 2: `prepare-handoff`

When usage limit is imminent, run:

```bash
bash ~/.claude/skills/orchestrate-handoff/scripts/prepare-handoff.sh cursor
# or
bash ~/.claude/skills/orchestrate-handoff/scripts/prepare-handoff.sh codex
```

Both targets read the existing `state.json` and `HANDOFF.md` (call `checkpoint.sh` first to refresh them).

**Cursor target:** prints a complete prompt to paste into Cursor agent mode. The prompt:
- Names the absolute repo path
- Tells Cursor to read `.orc/HANDOFF.md` and `.orc/state.json`
- Instructs Cursor to invoke `resume.sh`
- Emphasizes that Codex/Cursor worker daemons may still be running

**Codex target:** prints a `codex-rescue` agent prompt. Codex-rescue already knows the runtime — the prompt just declares "this is a resume, not a fresh start; load `.orc/HANDOFF.md` first."

## Mode 3: `resume`

Receiving agent invokes:

```bash
bash ~/.claude/skills/orchestrate-handoff/scripts/resume.sh
```

The script:
1. Reads `state.json` — fails clearly if missing
2. Re-attaches polling on in-flight jobs by running `poll-wave.sh` with the saved `ORCH_INFLIGHT_JOBS` triples (only if non-empty)
3. Prints a status table: which jobs finished while orchestrator was offline, which are still running, which failed
4. Echoes the routing file paths so the agent can Read them directly
5. Prints `ORCH_NEXT_ACTION` so the agent knows what to do next

After this, the receiving agent has full state and can continue `/orchestrate`'s Phase 2 loop, calling `checkpoint.sh` again after the next wave.

## Integration with `/orchestrate`

Two minimal edits to `~/.claude/skills/orchestrate/SKILL.md`:

1. **Phase 0, after routing probe:** export `ORCH_ROUTING_FILES`.
2. **Phase 2, end of per-wave loop:** export the wave env vars and call `checkpoint.sh`.

These edits are non-breaking — `checkpoint.sh` exits cleanly if env vars are partial.

## What does NOT get checkpointed

- **Worker outputs** — already on disk (files written, git diffs, codex/cursor logs). State only references paths and job IDs.
- **CC conversation transcript** — irrelevant; the orchestrator's *decisions* are captured in `ORCH_NOTES` and `ORCH_NEXT_ACTION`.
- **CLAUDE.md, ROUTER.md content** — paths only; resumer reads them fresh.

Keeps `state.json` small (~5–20KB).

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `resume` shows job as "unknown" | Job ID expired (codex 24h retention, cursor pid died) | Treat as failed; re-dispatch task |
| `state.json` missing | Checkpoint never ran | Reconstruct manually from plan file + git log |
| Routing files moved | Repo restructured between checkpoint and resume | Re-run Phase 0 of `/orchestrate` |
