---
name: verify
description: >
  Post-dispatch verification. Run a plan’s Acceptance checks; on pass, mark TaskNotes tasks
  completed, write a .mex pattern, and trigger Multica reverse sweep. On failure, generate a gap
  plan, post discovered tasks to TaskNotes, and trigger forward sweep. Manual: /orc:verify.
---

# Orc: Verify

Verification is where “agent said done” becomes “system is actually done”.

This skill should be invoked automatically at the end of `/orc:dispatch` (Phase 3) unless the user explicitly requests skipping verification.

## Inputs

- Optional plan reference:
  - A plan file path: `.orc/plans/<slug>.md`
  - Or a plan slug: `<slug>` (resolve to `.orc/plans/<slug>.md`)

If no input is provided, verify the active plan recorded in `.orc/state.json` (when present).

## Contract with scope / plan schema

The plan must include:

- `## Acceptance` with 1+ checks (bash/grep/review/manual)
- A `tasknotes_id` per task when scope posted tasks to TaskNotes (preferred)

If Acceptance is missing, fail fast: report “unverifiable plan” and instruct user to re-scope.

## Pass path

1. Run every Acceptance check.
2. If all pass:
   - Mark TaskNotes items completed:
     - Parent backlog task (if any): set `status=done` and `admin_state=completed`
     - Each per-task TaskNotes task referenced by plan: set `status=done` and `admin_state=completed`
   - Trigger Multica reverse sweep (edge event):
     - `bash skills/sync/scripts/bridge-trigger.sh --reverse`
   - Write `.mex/patterns/<plan-slug>.md` (if `.mex/` exists in repo):
     - Include: Task, Approach, Agent routing, Files touched, Verification summary

## Fail path (gap closure)

1. For each failing Acceptance check:
   - Diagnose root cause and propose a minimal fix.
2. Write `.orc/plans/<slug>-gaps.md` containing:
   - failing checks
   - diagnosis
   - concrete tasks to remediate (with Executors and new Acceptance)
3. Post discovered tasks to TaskNotes (best-effort):
   - `POST /api/tasks` with:
     - `title`: “<slug> gap: <short>”
     - `status`: `todo`
     - `agent_tag`: `claude-run`
   - Then use Obsidian CLI `property:set` (best-effort) on returned task path to set:
     - `task_type=development_task`, `admin_state=queued`, `source=orc_discovered`, `plan_slug=<slug>`
4. Trigger Multica forward sweep (edge event):
   - `bash skills/sync/scripts/bridge-trigger.sh --forward`
5. Offer to run: `/orc:dispatch .orc/plans/<slug>-gaps.md`

## Edge-event bridge rule (per user)

- Only trigger sweeps on verify pass/fail (and other “edge” writes), not on every per-wave PATCH.

