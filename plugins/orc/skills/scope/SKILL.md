---
name: scope
description: >
  Shape a backlog item or freeform idea into a scoped plan file before executing.
  Interactive: reads item context, explores relevant codebase, asks 1-2 clarifying questions,
  writes .orc/plans/<slug>.md that orc:dispatch can consume directly.
  Use when: "orc scope", "orc:scope", "scope this", "shape this idea", "plan before executing",
  "break this down", or when the user wants to refine an idea before committing to orc:dispatch.
  Part of the orc system: orc:dispatch, orc:backlog, orc:autoresearch, orc:status, orc:recap, orc:scope, orc:handoff.
---

# Orc: Scope

Bridge between a backlog item and orc:dispatch execution. Refine scope interactively before committing.

Core invariant: scope must produce a plan that is **verifiable** (`## Acceptance`) and **TaskNotes-addressable** (per-task `tasknotes_id` when API is up).

## Input

- `orc:scope <backlog-id>` — load from `.orc/backlog/items/<id>-*.md`
- `orc:scope <freeform description>` — scope from scratch

## Flow

1. **Load context**: Read the backlog item markdown (if from backlog) or parse the freeform description
2. **Explore codebase**: Read the files listed in the item's "Files involved" section. Check current state — has anything changed since the item was captured?
3. **Clarify** (max 2 questions via AskUserQuestion): Ask only if scope is ambiguous or there are meaningful alternatives. Skip if the item is already well-defined.
4. **Decompose**: Break into 2-8 tasks with:
   - Title + description
   - Executor routing (Claude direct / Cursor / Codex)
   - Dependencies between tasks
   - File paths per task
   - Guard command
5. **Acceptance (mandatory)**: Add a `## Acceptance` section with 2–8 checks:
   - Prefer bash/grep checks (tests, lint, search) when possible
   - If a task has no check, ask the user for a manual check description; do not omit acceptance
6. **Write plan**: Save to `.orc/plans/<slug>.md`
7. **TaskNotes fan-out (mandatory when API is up)**:
   - For each task in `## Tasks`, create a TaskNotes task:
     - `POST http://localhost:8080/api/tasks` with:
       - `title`: "<plan-slug>: <task title>"
       - `status`: "todo"
       - `agent_tag`: "claude-run"
   - Record the returned task id/path back into the plan under that task:
     - `- **tasknotes_id**: <...>`
   - Best-effort set typed fields via Obsidian CLI `property:set` on the returned path:
     - `task_type=development_task`, `admin_state=queued`, `worker=<executor>`, `plan_slug=<slug>`, `source=orc_scope`
   - Trigger Multica projection once (edge event): `bash skills/sync/scripts/bridge-trigger.sh --forward`

## Plan file format

```markdown
# <Title>

Source: .orc/backlog/items/<id>.md (or "freeform")
Scoped: <date>
Guard: <command>

## Tasks

### 1. <Task title>
- **Executor**: Cursor
- **Files**: path/to/file.py
- **Description**: What to do
- **Depends on**: none
- **tasknotes_id**: 100 Tasks/TaskNotes/Tasks/<...>.md

### 2. <Task title>
- **Executor**: Codex
- **Files**: path/to/new_file.py, path/to/existing.py
- **Description**: What to do
- **Depends on**: Task 1
- **tasknotes_id**: 100 Tasks/TaskNotes/Tasks/<...>.md

## Acceptance

- [ ] `<bash cmd>` → <expected>
- [ ] <manual check> [manual]

## State delta since capture

<What changed in the codebase since the backlog item was created — helps orc:dispatch adjust>
```

## After scoping

Offer two choices:
1. **Execute now** — invoke `orc:dispatch .orc/plans/<slug>.md`
2. **Save for later** — keep the plan file, return to conversation

If the item came from backlog, update its status in BACKLOG.jsonl to `"scoped"`.
