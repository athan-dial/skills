---
name: sync
description: >
  TaskNotes-first sync for orc. Pull shaped, agent-tagged tasks from TaskNotes into the local
  .orc/backlog cache; push local captures/discovered work back to TaskNotes. Edge-trigger the
  Multica bridge (just sweep-forward / sweep-reverse) after significant writes.
  Manual: /orc:sync [--pull|--push] [--project <slug>] [--dry-run] [--no-bridge].
---

# Orc: Sync (TaskNotes ↔ orc cache ↔ Multica)

TaskNotes is the **source of truth**. orc keeps a **local display cache** at `.orc/backlog/` so sessions are fast/offline-friendly.

This skill is responsible for:

- Pulling project-scoped tasks from TaskNotes into `BACKLOG.jsonl`
- Pushing locally-captured items to TaskNotes (best-effort)
- Triggering Multica projection sweeps **only on edge events** (not on every per-task PATCH)

## Inputs

- `--pull`: TaskNotes → orc cache only
- `--push`: orc cache → TaskNotes only
- `--project <slug>`: override project scoping (defaults to `.orc/state.json.project_slug` if present)
- `--dry-run`: print intended actions, no writes
- `--no-bridge`: do not trigger `just sweep-*`

## Pull contract (TaskNotes → orc)

Pull tasks where:

- `agent_tag ∈ {claude, claude-run, claude-show, claude-mcp}` (from API payload or recovered from frontmatter)
- `shaped: true` (frontmatter)
- `project_slug == <active project>` (frontmatter) when available
- `status` is not terminal (`done`, `cancelled`, `completed`, `closed`)

Cache schema (`.orc/backlog/BACKLOG.jsonl`) is JSONL, keyed by `tasknotes_id` (the TaskNotes id/path):

```json
{"id":"001","tasknotes_id":"100 Tasks/TaskNotes/Tasks/Foo.md","title":"Foo","priority":"p2","agent_tag":"claude-run","task_type":"development_task","admin_state":"queued","approval":"review","worker":"cursor-agent","project_slug":"talos","source":"manual","plan_slug":null,"multica_id":null,"synced_at":"2026-04-21T15:00:00Z","status":"open"}
```

Notes:

- `id` is cosmetic (local numbering). The primary key is `tasknotes_id`.
- This file is a cache: it may be regenerated at any time.

## Push contract (orc → TaskNotes)

Push only items that do **not** have `tasknotes_id` yet (local captures), plus any queued `pending_writes` in `.orc/state.json` (if present).

For each pushed item:

- `POST /api/tasks` with at least `{title, status:"todo", agent_tag:"claude-show"}` unless user provided overrides.
- Best-effort set typed fields via Obsidian CLI `property:set` when available:
  - `task_type=development_task`
  - `admin_state=observed`
  - `project_slug=<active project>`
  - `source=orc_capture`

## Multica bridge triggers (edge events only)

When `--no-bridge` is not set, trigger:

- After a pull that adds/removes any cached items: `just sweep-forward`
- After a push that created any new TaskNotes tasks: `just sweep-forward`
- After a verify pass that completed tasks: `just sweep-reverse`

Never run sweeps per wave per task. Prefer once at wave-start, wave-end, verify-pass, verify-fail.

## Implementation

Run:

```bash
bash "$(dirname "$0")/scripts/sync.sh" $ARGUMENTS
```

