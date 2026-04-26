---
name: state
description: >
  Cheap one-liner mutations to .orc/state.json. Use for incremental updates
  during a dispatch run when the full checkpoint.sh is too heavy or when
  surgically changing a single field. Triggers: /orc:state, "update orc state",
  "stamp inflight job", "add note to state". All mutations bump last_activity_at.
---

# Orc: State

Tiny mutator over `.orc/state.json`. Pairs with `checkpoint.sh` (full reconciliation)
and `tripwire.sh` (proactive handoff trigger). Use this when you want to update one
field without re-detecting everything.

## Subcommands

```
state show                            # print state.json (pretty)
state set <key> <value>               # set top-level key (auto-coerces int/bool/float)
state set-json <key> <json-literal>   # set key with raw JSON value (arrays, objects)
state add-job <agent:id:label>        # append to inflight_jobs[]
state clear-jobs                      # reset inflight_jobs to []
state touch                           # bump last_activity_at + git_head only
state note <text>                     # append timestamped line to notes
```

## When to use which

| Need | Tool |
|---|---|
| Reconcile entire state from disk | `checkpoint.sh` (auto-detects everything) |
| Surgically update one field | `state set <key> <val>` |
| Note a decision mid-wave | `state note "C2 reroute to Cursor"` |
| Track a newly dispatched job | `state add-job cursor:cur-abc:track-projects` |
| Just bump activity time | `state touch` |
| Decide whether to handoff | `tripwire.sh` (advisory) |

## Examples

```bash
# Mid-wave job tracking
bash skills/state/scripts/state.sh add-job cursor:cur-1234:track-projects
# ... later when it completes ...
bash skills/state/scripts/state.sh clear-jobs

# Annotate a decision
bash skills/state/scripts/state.sh note "Skipped C3 — failed differentiation gate"

# Override a single field
bash skills/state/scripts/state.sh set wave 3
bash skills/state/scripts/state.sh set wave_status running
```

## Bootstrap

If `.orc/state.json` doesn't exist yet, the `state` script writes a one-line
warning to stderr and exits 1. Run `checkpoint.sh` first to bootstrap.

## Coexistence with checkpoint.sh

`state` is a fine-grained mutator. `checkpoint.sh` is coarse — it reads disk + git +
prior state and rewrites the whole file. Both coexist; both bump `last_activity_at` as
a side effect. Calling `state` between checkpoints keeps the SessionStart hook's
freshness gate happy without paying for full re-detection.
