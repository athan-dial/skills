# orc-plan/1 Format Reference

Canonical schema for `plan.yaml` consumed by `/orc:dispatch`.

## Required top-level fields

| Field | Type | Notes |
|---|---|---|
| `format_version` | string | Must be exactly `orc-plan/1`. |
| `slug` | string | Lowercase, hyphenated, ≤40 chars. Used as the directory name and dispatch handle. |
| `title` | string | One-line human description. |
| `guard` | object | At least one guard command. Keys: `python`, `frontend`, `custom`. Values are shell strings. |
| `waves` | array | Ordered. Wave 0 if present must be `serial: true`. |

## Wave shapes

### Serial wave (typically Wave 0)

```yaml
- wave: 0
  label: Shared shims
  serial: true
  prs:
    - id: w0-01
      prompt: prompts/w0/01-add-helper.txt
      expected_files: [tauri-app/src/lib/api.ts]
      agent: cursor
```

`prs` is an ordered list. Each PR runs after the previous PR completes.

### Parallel wave (typically Wave 1+)

```yaml
- wave: 1
  label: Feature rollout
  tracks:
    - id: projects
      cursor_wt: wt-projects
      prs:
        - id: w1-projects-01
          prompt: prompts/w1/track-projects/01-grid.txt
          expected_files: [tauri-app/src/views/Projects.tsx]
          agent: cursor
```

Each track runs in its own isolated cursor worktree (via `cursor_wt`). Tracks within a wave run in parallel; PRs within a track run serially.

## Per-PR fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | Unique within the plan. Convention: `w<wave>-<track>-<NN>` or `w<wave>-<NN>`. |
| `prompt` | string | yes | Path relative to the plan dir. File must exist. |
| `expected_files` | array | yes | Non-empty list of repo-relative paths the PR is expected to modify. Verification bar at dispatch time. |
| `agent` | string | yes | One of: `cursor`, `codex`, `claude-direct`, `claude-subagent`. |
| `notes` | string | no | One-line context, surfaced in dispatch logs. |

## Validation invariants

`/orc:dispatch` enforces these before executing:

1. `format_version == "orc-plan/1"` (exact match).
2. `slug` matches `^[a-z][a-z0-9-]{0,39}$`.
3. Every `prompt` path resolves to a file inside the plan dir.
4. Every PR has `expected_files` with ≥1 entry.
5. **Within a single wave**, no two tracks list the same path in `expected_files`. (The single largest source of merge conflict — caught at plan time it costs nothing; caught at dispatch time it costs a 3-way merge.)
6. Every `cursor_wt` is unique across the entire plan.
7. At least one guard command is present.

If any invariant fails, dispatch prints the specific error and refuses to execute.

## Prompt file contents

Each prompt file is a plaintext brief sent verbatim to the worker. It should include:

1. **Repo location** + non-negotiables (read `CLAUDE.md` if present in the repo).
2. **Specific files to read first** — not general "explore the codebase".
3. **Specific deliverable** — which files to create/modify.
4. **Scope constraint** — "Do NOT commit. Minimal focused diff."
5. **Guard command** — what to run before reporting done.

Example skeleton — see `assets/prompt-template.txt` for a copyable starting point.

## Why the format is strict

The validation rules exist because the orchestrator made a specific tradeoff:

- **Pre-execution validation is cheap** (parse YAML, set-intersect a few lists).
- **Mid-execution conflict resolution is expensive** (3-way merges, scope drift, retry loops).

Every invariant in this spec corresponds to a real failure mode observed at dispatch time. The plan format is the contract that makes the executor dumb and the planner smart.
