---
name: plan
description: >
  Multi-agent orchestration — break complex work into parallel sub-tasks dispatched to Cursor,
  Codex, or Claude subagents. Use when a task has multiple independent sub-parts that benefit
  from parallel agent execution. Triggered by /orc:plan, "orc plan", /orchestrate,
  /orchestrate path/to/plan.md, "orchestrate this", "execute this plan with agents",
  "break this down and run it", "run these in parallel", "dispatch this work",
  or any request with 2+ independent sub-parts.
  Works with any markdown plan file, .orc/plans/ scoped plan, or freeform request.
  Part of the orc system: orc:plan, orc:add, orc:list, orc:pick, orc:scope, orc:autoresearch, orc:status, orc:recap, orc:handoff.
---

# Orc: Plan

Framework-agnostic multi-agent orchestrator. Read a plan or freeform request, decompose into dependency-ordered tasks, dispatch to Codex/Cursor/Claude workers in parallel waves, poll, review, and advance — autonomously until complete.

## Workflow

```
Input (plan file or freeform request)
  → Decompose into tasks with dependencies
  → Present table for user confirmation
  → Wave-based execution (dispatch → poll → review → advance)
  → Verification + summary
```

## Autonomy Mode (default)

Once the user confirms the task table, operate autonomously to completion:
- Dispatch all Wave 1 tasks immediately (all agents in parallel — Codex, Cursor, Claude subagents simultaneously)
- Poll → review → dispatch Wave 2 without pausing
- Only stop to ask if: a destructive op is needed (migration, force push), all retries on a task are exhausted, or a blocking ambiguity cannot be resolved from the codebase
- On completion, present a single summary: what changed, what was skipped, any issues

**Do not** ask for permission between waves or report "starting wave 2" as a question — just do it.

## Phase 0: Route (auto — .mex-aware repos)

**Runs BEFORE any planning subagent (Explore/Plan/researcher) is spawned.** Planning subagents inherit CLAUDE.md but do not automatically discover `.mex/` — they just Glob/Grep, and ripgrep skips `.mex/` if it's gitignored. If the orchestrator doesn't pre-read routing and inject it into every subagent prompt, planning proceeds blind to repo conventions and the resulting task decomposition is wrong.

**Step 1 — Probe (single shell call, instant).**

```bash
for root in . ..; do
  [ -f "$root/.mex/ROUTER.md" ] && echo "MEX_ROUTER=$root/.mex/ROUTER.md"
  [ -f "$root/CLAUDE.md" ] && echo "CLAUDE_MD=$root/CLAUDE.md"
done
```

If neither is found: skip to Phase 1 normally.

**Step 2 — Read ROUTER.md yourself (the orchestrator), not via subagent.** Extract:
- The routing table (task type → context file mapping)
- The behavioral contract (ROUTE/GROUND/EXECUTE/VERIFY/GROW)
- "Current Vault State" or equivalent known-issues section

This is a ~100-line read that pays for itself by preventing every downstream subagent from rediscovering structure via Glob.

**Step 3 — Every planning subagent prompt MUST open with a Routing Preamble.** Applies to `Explore`, `Plan`, `researcher`, `feature-dev:code-explorer`, any `general-purpose` Agent call made during planning.

Template:
```
## Repo routing (read these first — they override codebase inference)
- `<repo>/.mex/ROUTER.md` — routing table + behavioral contract
- `<repo>/.mex/context/<domain-1>.md` — <why relevant to this exploration>
- `<repo>/.mex/context/<domain-2>.md` — <why>
- `<repo>/CLAUDE.md` — hard rules

Do NOT rely on Glob/Grep to discover conventions — `.mex/` may be gitignored
and invisible to ripgrep. Read the files above explicitly via Read tool.
```

Pick which `.mex/context/*.md` files to name by matching the exploration question against the routing table you loaded in Step 2. Don't dump the whole list — 2–3 targeted files.

**Step 4 — Follow the behavioral contract at the orchestrator level** (ROUTE → GROUND → EXECUTE → VERIFY → GROW).

**Step 5 — Export routing context for handoff:** `export ORCH_ROUTING_FILES=$'<path1>\n<path2>\n...'` listing the `.mex/context/*.md` files you loaded. Used by the `orchestrate-handoff` skill to checkpoint state so a fresh CC/Cursor/Codex session can re-attach if you hit a usage limit mid-run.

**Why this matters:** The failure mode you're fixing is "planning subagent produced a decomposition that ignores repo conventions." It happens because subagents don't know `.mex/` exists. The only reliable fix is the orchestrator reading ROUTER itself, then handing each subagent a named list of files to Read. Telling them "check for routing files" isn't enough — they have to be handed the paths.

## Phase 1: Decompose

**Plan file input:** Read the file, extract discrete tasks from sections/steps/checklists.

**Freeform input:** Decompose into 2-15 independent sub-tasks.

Each task needs:
- **Title** — short, action-oriented
- **Description** — what to do, which files, patterns to follow
- **Agent** — `codex`, `cursor`, or `claude` (see `references/routing.md`)
- **Dependencies** — which tasks must complete first
- **File paths** — files involved

Create tasks via TaskCreate with dependency links (addBlockedBy/addBlocks). **Always set `activeForm`** on every task — the harness renders this as a live spinner while the task is `in_progress`, giving the user native Claude Code-style progress visibility at zero token cost.

```
TaskCreate({
  subject: "Create User model",
  activeForm: "Building User model via Codex",
  description: "..."
})
```

Present as a table, then confirm with AskUserQuestion — choices: "Execute all", "Edit assignments", "Abort".

## Phase 2: Execute Waves

Group by dependency order:
- **Wave 1:** Tasks with zero dependencies
- **Wave 2:** Tasks whose deps are all in Wave 1
- etc.

**Simple case (<=3 independent tasks, no deps):** Skip formal waves — dispatch all in parallel, collect results.

Per wave:
1. Dispatch all tasks simultaneously
2. Poll until all complete (see Polling Protocol)
3. Review each output (see Review Protocol)
4. Mark complete or retry
5. **Checkpoint** — see Checkpointing below
6. Dispatch newly-unblocked tasks immediately

### Checkpointing (handoff-resilient)

After step 4 of every wave (review complete), call the `orchestrate-handoff` skill so a fresh agent can resume if CC hits a usage limit:

```bash
export ORCH_PLAN_REF="<plan-path-or-freeform:hash>"
export ORCH_WAVE=<n>
export ORCH_WAVE_STATUS="complete"   # or "polling" if calling mid-wave
export ORCH_INFLIGHT_JOBS=$'agent:job_id:label\n...'   # empty if none
export ORCH_NEXT_ACTION="Dispatch wave <n+1>: tasks X, Y"
export ORCH_NOTES="<recent reroutes, blockers, decisions>"
# ORCH_ROUTING_FILES already exported in Phase 0
bash ~/.claude/skills/orchestrate-handoff/scripts/checkpoint.sh
```

Writes `<repo>/.orchestrate/{state.json,HANDOFF.md}`. Idempotent. If you sense a usage limit is imminent, run `prepare-handoff.sh cursor` or `prepare-handoff.sh codex` for a paste-ready resume prompt.

## Phase 3: Complete

1. Run verification commands from the plan (tests, lint, type-check) if specified
2. Show final status table
3. Summarize what was built/changed

## Dispatch Commands

### Codex (heavy tasks — new files, multi-function, >100 LOC)

```bash
COMPANION="$(command -v codex-companion 2>/dev/null || find ~/.claude/plugins -name codex-companion.mjs 2>/dev/null | head -1)"

# Dispatch (returns job ID)
$COMPANION task --background --write "<prompt>"

# Poll
$COMPANION status <job-id>

# Full result
$COMPANION result <job-id>

# Resume/fix
$COMPANION task --resume-last --write "<follow-up>"
```

**Parallelism:** Multiple Codex jobs can run simultaneously — the companion tracks all by job ID via `--all --json`. Dispatch up to 3 concurrent Codex jobs; beyond that, queue by dependency order.

### Cursor (lighter tasks — single-file edits, config, migrations)

```bash
CURSOR="$(command -v cursor-task 2>/dev/null || find ~/.claude/skills -name cursor-task.sh 2>/dev/null | head -1)"

# Dispatch (returns job ID)
bash $CURSOR "<prompt>"

# Poll
bash $CURSOR --status <job-id>

# Full result
bash $CURSOR --result <job-id>

# Continue/fix
bash $CURSOR --continue "<follow-up>"
```

**Constraint:** Max 3 parallel Cursor tasks.

### Claude direct (trivial — reads, commands, checks)

Use Bash, Read, Write, Edit directly. No dispatch overhead.

### Claude subagent (MCP-dependent — Slack, Jira, Confluence)

```
Agent(subagent_type="general-purpose", prompt="...")
```

Use `Explore` for codebase search, `researcher` for Slack/Confluence, `vault-explorer` for vault notes.

## Prompting Workers

Every worker prompt MUST include — see `references/prompts.md` for templates:
1. **Context to load first** — from Phase 0: relevant `.mex/context/*.md` + `CLAUDE.md` paths. Omit only if neither exists.
2. **What to do** — specific instructions
3. **File paths** — exact paths to read/create/modify
4. **Patterns** — point to an existing file as example ("follow the pattern in src/models/user.py")
5. **Exclusions** — what NOT to modify
6. **Signatures** — when the task must match an interface

Workers read the codebase themselves — point to paths, don't paste code.

## Polling Protocol

**Goal:** Rich, frequent status visibility without model token drain. The harness streams Bash stdout in real-time — delegate polling to a shell script so the user sees live updates while the model pays zero tokens.

### Shell-Driven Polling (preferred)

After dispatching all jobs in a wave, run `scripts/poll-wave.sh` as a **single foreground Bash call**:

```bash
zsh ~/.claude/skills/orc/scripts/poll-wave.sh \
  codex:cdx-abc:UserModel \
  cursor:cur-def:APIEndpoint \
  cursor:cur-ghi:Config
```

Arguments: `agent:job_id:label` for each dispatched job.

Supported agent types:
- **`codex`** — polls via `codex-companion.mjs status --all --json`. Extracts running/finished state from JSON.
- **`cursor`** — polls PID liveness + tails the log file. Shows last meaningful output line and log growth rate (`+NL`) as activity hints.
- **`claude-bg`** — polls a sentinel file at `$TMPDIR/claude-bg-<job_id>.status`. Write to this file from background Agent/Bash calls to report progress.

Options: `--interval 5` (poll frequency, default 5s — feels near-real-time), `--timeout 1200` (max wait, default 20min).

The dashboard feels **live** by design:
- **Braille spinner** (⠋⠙⠹…) in the frame header advances every render — visible proof the poller is alive even in quiet stretches.
- **Per-job elapsed timer** (yellow `m:ss`) ticks up every poll on running rows — especially important for Codex jobs, whose underlying status API only exposes coarse phase metadata and otherwise looks frozen between transitions.
- **Always re-renders while any job is running** (no waiting for a status change). When all jobs are pending/idle, it falls back to a 15s heartbeat so the header timer still ticks visibly.
- **Cursor activity** column tails the log file, showing the last meaningful line plus a growth counter (`+NL`).

**Agent choice affects perceived motion:** Cursor rows feel dramatically more alive than Codex rows because log tails produce evolving text each poll; Codex only surfaces phase transitions (verifying, running command…). If a user wants visible motion on a borderline task, route it to Cursor. Single-job waves inherently look static — multi-job waves show rows flipping independently and the progress bar filling in steps.

**Architecture:**
```
Model dispatches workers → Model launches poll-wave.sh (1 Bash call)
  ↓ (streaming stdout — zero tokens)                    ↓
  User sees live status + activity table          Script exits
  ↓                                                      ↓
Model retrieves results → Model reviews (tokens only here)
```

### Fallback: Monitor-Based Polling (pure claude-bg waves)

Use when a wave contains **only `claude-bg` jobs** and `poll-wave.sh` would be overkill (no Codex/Cursor jobs). Requires each Agent call to write a sentinel on completion.

**Step 1 — Each background Agent must write its sentinel when done:**

```python
# At the end of every claude-bg agent prompt, instruct it to write:
# echo "done" > "${TMPDIR:-/tmp}/claude-bg-<job_id>.status"
```

**Step 2 — Launch Monitor instead of poll-wave.sh:**

```python
Monitor(
  description="claude-bg wave — <wave label>",
  command="zsh ~/.claude/skills/orc/scripts/watch-claude-bg.sh job1 job2 job3",
  timeout_ms=1200000,
  persistent=False
)
```

The Monitor emits one line per status change (`job_id: done`, `job_id: failed`, `all_done`, `timeout`). Each line arrives as a notification — the model is free to do other work until `all_done` fires. No repeated manual checks.

**On `all_done` notification:** retrieve results and advance to the next wave.  
**On `timeout`:** flag to user with what was attempted.

### Task Status Sync

When `poll-wave.sh` reports a job as done/failed, immediately update the corresponding task:
```
TaskUpdate({ taskId: "N", status: "in_progress", activeForm: "Reviewing Codex output" })
```
This flips the harness spinner to show the review phase — another free visual cue.

## Review Protocol

After each worker completes:
1. `git diff HEAD~1 -- <changed files>` to see changes
2. Read critical sections (signatures, imports, key logic)
3. Check: wrong imports, pattern violations, incomplete implementations (TODOs, placeholders), out-of-scope modifications
4. Pass → TaskUpdate to "completed", dispatch unblocked tasks
5. Fail → send follow-up via resume/continue with specific fix instructions

## Status Display

### Live polling (shell-streamed, zero tokens)

`poll-wave.sh` renders a framed Unicode dashboard with ANSI color to the terminal:

```
╭─ Orchestration ──────────────────────────── 02:45 ─╮
│  ████████████░░░░░░░░  3/5  ▸ 2 active             │
│                                                     │
│  ✓ done      Taxonomy restructuring   codex         │
│  ✓ done      Claim extractor update   cursor        │
│  ⏳ running   Config migration     codex  +12L   │
│  ⏳ running   EDGAR pre-filter         claude        │
│  ◻ pending   Backfill management      —             │
╰──────────────────── 3/5 tasks · 2 agents active ───╯
```

Status glyphs: `✓` done (green), `⏳` running (yellow), `✗` failed (red), `◻` pending (dim), `⊘` cancelled (dim).
Agent badges are color-coded: codex=magenta, cursor=cyan, claude=white.
Progress bar fills green on wave completion.

### Between-wave summaries (model-rendered markdown)

When emitting status between waves or at completion, use a fenced code block with Unicode framing (safer than markdown tables which can misrender at full terminal width):

```
╭─ Wave 2 complete ─────────────────────────── 04:12 ─╮
│                                                      │
│  ✓ 2A  Taxonomy restructuring         Codex    1m32  │
│  ✓ 2B  Claim extractor update         Cursor   2m08  │
│  ✓ 2D  Config migration           Codex    3m45  │
│  ✓ 2E  EDGAR pre-filter               Claude   1m10  │
│                                                      │
│  ▸ Unblocked: 3A (Backfill management)               │
│  ▸ Next: Wave 3 — 1 task dispatching now             │
│                                                      │
╰──────────────────────────── 4/8 tasks complete ──────╯
```

At final completion, append a summary line below the frame:
```
✓ All 8 tasks complete in 12m 34s — 3 agents used (2 Codex, 1 Cursor)
```

## Constraints

- **Proactive dispatching** — dispatch immediately when tasks unblock, don't wait for user
- **Don't do workers' jobs** — re-dispatch with better instructions rather than doing it directly
- **Ask before destructive ops** — migrations, DB changes, force pushes need user approval
- **Read-only ops are free** — never ask permission to read files, check status, or review diffs

## Error Handling

- Worker error → permissions/config issue (fix locally) vs. code issue (re-dispatch with fixes)
- Wrong files modified → `git checkout -- <wrong files>`, re-dispatch
- All retries exhausted → flag to user with what was attempted

## Fallback & On-the-Fly Reassignment

When a dispatched worker fails mid-wave, **do not block the wave waiting for the original agent to recover** — reassign immediately to keep dependent tasks unblocked.

### Detection signals

Check status output for each signal; don't wait for a full timeout if the signal is already visible.

| Signal in status output | Failure mode | Original agent recoverable? |
|---|---|---|
| `"hit your usage limit"` / `"try again at <time>"` | Rate limit | Only after reset (often 30–60min) |
| `"Connection lost"` / `"Retry attempt N..."` repeated | Transient network | Yes, usually self-recovers |
| Status = `failed` + duration < 30s | Auth / config / quota | No — fix underlying, then retry |
| Status = `running` + elapsed > 2× typical + log growth = 0 | Hung / stalled | No — cancel and reroute |
| Status = `failed` + stderr cites code issue | Worker produced a bug | Yes — re-dispatch same agent with fix instructions |

### Reassignment decision

When the original agent cannot recover in time, pick the fallback by the task's size, not its original routing:

| Original | Task shape | Fallback |
|---|---|---|
| Codex | Multi-file, >100 LOC | **Cursor** (slower per-task but can handle it); if Cursor at parallel cap, **Claude direct** |
| Codex | Single-concern service | **Cursor** |
| Cursor | Any | **Codex** if parallel slot open; else **Claude direct** |
| Either | Simple spec, clear file paths, <200 LOC total | **Claude direct** via Write/Edit (zero wait, costs tokens) |

**Bias toward Claude direct for small well-specified tasks** when both external agents are unavailable. The plan file already contains the spec — just execute it.

### Reassignment protocol

1. **Do not mark the task completed.** Leave it `in_progress` with the new owner.
2. **Cancel the stuck job** (if still running): `codex-companion.mjs cancel <job_id>` or `cursor-task.sh --cancel <job_id>`. Skip if already `failed`.
3. **Re-dispatch to the fallback agent** using the same prompt text (the original dispatch prompt is still correct). For Claude direct, open the plan file for the task spec and execute inline.
4. **Tell the user in one line** what just happened: `"Codex rate-limited (resets ~12:11). Rerouting W2-C1 to Claude direct."` — no AskUserQuestion, no approval pause. This is autonomous recovery.
5. **Preserve the task ID** in TaskUpdate; don't create a duplicate task.
6. **Continue the wave.** Other parallel tasks keep running; reassignment doesn't block them.

### When to stop and ask

Escalate to the user only if:
- **All three execution paths** (Codex, Cursor, Claude direct) are unavailable or have failed on the same task
- The task requires a destructive op (migration, force push, external API with side effects) that wasn't pre-authorized
- The failure signal suggests a systemic issue (e.g., every Codex job fails at 0s with an auth error)

### Example (real session)

```
Wave 2 dispatched: Codex (C1), Cursor (C2).
poll → C1 status=failed, "hit your usage limit, try again at 12:11 PM"
  → Codex unrecoverable for ~45min. C2 still running on Cursor.
  → Cursor at 1/3 parallel slots — but C1 spec is small (single service file + tests).
  → Decision: Claude direct. Faster than waiting, cheaper than blocking Wave 3.
  → Execute inline with Write + Edit. Tests pass 7/7 in ~5min.
  → Continue to Wave 3 without waiting for Codex reset.
```
