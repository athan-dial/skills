---
name: plan
description: >
  Interactive grill-style interview that produces a dispatch-ready plan directory in the
  orc-plan/1 format. Walks the user one question at a time through PR scope, file ownership,
  shared shims, and agent routing — then serializes the answers to .orc/plans/SLUG/.
  Triggered by /orc:plan, "plan a roadmap", "grill me on this plan", "produce a dispatch plan",
  "structure a parallel rollout". Output is consumed by /orc:dispatch.
  Part of the orc system: orc:plan, orc:dispatch, orc:status, orc:handoff.
---

# Orc: Plan

Interview-driven planner that produces a dispatch-ready directory `/orc:dispatch` can execute without further LLM decomposition.

## Workflow

```
User intent (freeform or rough plan file)
  → Relentless one-question-at-a-time interview (grill-me style)
  → Structured-output discipline at the end
  → .orc/plans/<slug>/ written to disk
  → Print "Run /orc:dispatch <slug>" — DO NOT auto-fire
```

## Interview Style

Inherit from grill-me: ask **one question at a time**, walk the decision tree, prefer codebase exploration over asking when the answer is on disk. Don't batch questions; don't accept "let's figure that out later" on load-bearing decisions.

For each question, propose a recommended answer. The user can accept, override, or ask for tradeoffs.

## Required Output

Write to `<repo>/.orc/plans/<slug>/`:

```
.orc/plans/<slug>/
  plan.yaml                    # manifest in orc-plan/1 format
  prompts/
    w0/01-<pr-name>.txt         # Wave 0 (shared shims, serial)
    w1/track-<id>/01-<pr>.txt   # Wave 1 (parallel tracks)
    w1/track-<id>/02-<pr>.txt   # serial within track
    ...
```

Slug rules: lowercase, hyphenated, ≤40 chars. Examples: `hermes-ui-1`, `auth-rewrite`, `q3-cleanup`.

## Plan Manifest (orc-plan/1)

`plan.yaml` schema. Reference: see `references/format.md` for the full spec; here's the shape:

```yaml
format_version: orc-plan/1
slug: <slug>
title: <one-line description>
guard:
  python: <test command, or omit>
  frontend: <typecheck/build command, or omit>
  custom: <any other guard, or omit>
waves:
  - wave: 0
    label: Shared shims (must land before parallel tracks)
    serial: true
    prs:
      - id: w0-01
        prompt: prompts/w0/01-add-helper.txt
        expected_files: [path/to/file.ts]
        agent: cursor                    # cursor | codex | claude-direct | claude-subagent
        notes: "one-line context"        # optional
  - wave: 1
    label: Parallel feature tracks
    tracks:
      - id: <track-name>
        cursor_wt: wt-<track-name>       # unique worktree name per track
        prs:
          - id: w1-<track-name>-01
            prompt: prompts/w1/track-<track-name>/01-foo.txt
            expected_files: [path/to/feature.tsx, path/to/feature.test.tsx]
            agent: cursor
```

Validation invariants `/orc:dispatch` will enforce — anticipate them while authoring:
- Every `prompt` file must exist on disk
- Within a single wave, no two tracks may list the same path in `expected_files` (collision)
- Every track has a unique `cursor_wt` name
- Every PR has at least one entry in `expected_files`
- `format_version` must be `orc-plan/1`

If the plan can't satisfy collision-freedom, extract the contended file into a Wave 0 PR and have parallel tracks read-only-consume the helper.

## Interview Order

Walk this tree. Skip a branch only if the codebase or earlier answers settle it.

### A. Scope intake
- "What's the goal in one sentence?"
- "Is there an existing plan file (markdown, roadmap doc, PRD)? If yes, path."
- "Rough PR count estimate?" — bucket: 1–4, 5–10, 11–25, >25.

### B. Slug + title
- Propose a slug derived from the goal; confirm.
- Confirm one-line title.

### C. Guards
- Detect the stack yourself (read `package.json`, `pyproject.toml`, `justfile`, `Makefile`).
- Propose a `python` guard if Python project, `frontend` if a Node/Tauri app, etc.
- Confirm or override.

### D. PR enumeration
- Walk the user through each PR. For each:
  1. Title (action verb + object)
  2. Files it touches (read the codebase to verify; don't accept hand-waving)
  3. Estimated diff size: `<50` / `50–200` / `>200` LOC
  4. Agent suggestion based on size: `<50` → cursor, `50–200` → cursor or codex, `>200` → codex
- Push back on PRs that touch >5 files unless explicitly justified.

### E. Ownership matrix
- After PRs enumerated, build the file × PR matrix.
- For any file owned by multiple PRs in the same wave: ask "Extract to Wave 0, merge PRs, or serialize in one track?"
- Iterate until no in-wave collisions remain.

### F. Wave structure
- Wave 0: shared shims (helpers added to lib/api.ts, new types, routing-table additions, schema migrations). Serial.
- Wave 1+: parallel tracks where each track owns disjoint files. Serial within a track.
- Recommend track grouping by feature boundary, not by file. Confirm.

### G. Per-PR prompt drafting
- For each PR, draft the prompt file content. Each prompt must include:
  1. Repo path + non-negotiables (read CLAUDE.md if present)
  2. Specific files to read first (not general "explore the codebase")
  3. Specific deliverable: which files to create/modify
  4. Constraint: "Do NOT commit. Minimal focused diff."
  5. Guard command to run before reporting done
- Show the user the first 1-2 drafts; if accepted, generate the rest in the same shape.

### H. Final review
- Print the assembled `plan.yaml` for the user.
- Ask: "Ship this to disk?"
- On confirm: write all files. Print:
  ```
  Plan written: .orc/plans/<slug>/
  Run: /orc:dispatch <slug>
  ```

## Codebase Exploration

When a question can be answered by reading the codebase, do so instead of asking. Examples:
- Test command → check `justfile`, `package.json` scripts, `Makefile`, `pyproject.toml`.
- Where X currently lives → grep / find first.
- Current shape of file Y → Read it.

Only ask the user when the answer requires their judgment (priorities, tradeoffs, scope).

## What NOT to Do

- Do NOT auto-fire `/orc:dispatch` on completion. Print the slug and stop.
- Do NOT generate prompts that say "explore the codebase" — be specific about which files.
- Do NOT skip the ownership-matrix step. In-wave file collisions are the #1 source of merge pain at dispatch time; catching them at plan time is free.
- Do NOT accept PRs with empty `expected_files`. The list is the verification bar `/orc:dispatch` enforces.
- Do NOT batch questions. One at a time, with a recommended answer.
- Do NOT add Wave 0 PRs that are pure busywork. Only extract a shim when it would unblock parallelism otherwise.

## On Existing Plan Files

If the user provides a markdown plan file (PRD, roadmap, RFC):
- Read it fully first.
- Use it to pre-populate PR enumeration.
- Still walk the ownership-matrix and per-PR prompt steps — markdown plans rarely include the file-level scope discipline `/orc:dispatch` needs.

## On Tiny Inputs

If the user says "make this one small change," skip the full grill. Produce a one-PR Wave 0 plan with one prompt file. The point is to be useful, not ceremonial.
