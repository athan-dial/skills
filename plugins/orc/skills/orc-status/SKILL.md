---
name: orc:status
description: >
  Single-pane view of all orc system activity: active orchestration, running autoresearch loops,
  backlog count, last commit. Use when: "orc status", "orc:status", "what's running",
  "what's the state", "show me orc", or at session start to orient.
  Part of the orc system: orc:plan, orc:backlog, orc:autoresearch, orc:status, orc:recap, orc:scope, orc:handoff.
---

# Orc: Status

Delegate to `scripts/render-status.sh` — zero model tokens, streamed to the user's terminal:

```bash
bash scripts/render-status.sh              # auto-detect repo root from CWD
bash scripts/render-status.sh --root PATH  # override
```

The script reads four sources and renders a calm four-row dashboard:

1. `.orc/state.json` — active orc:plan orchestration (wave, task counts, agent status)
2. `var/autoresearch/*/session.json` — running autoresearch loops (iteration, metric, delta)
3. `.orc/backlog/BACKLOG.jsonl` — open items with priority breakdown
4. `git log -1` — last commit for context

Example (active work):

```
  orc  ·  taxonomy-work

  ● plan           taxonomy-restructure                   wave 2/3 · 3 running
  ● autoresearch   coverage-push                 iter 14/50 · 68.2% · (+2.3pp)
  · backlog        3 open                                   1 p1 · 1 p2 · 1 p3
  · last commit    feat: wire up the thing              bfbb0c2 · 1 second ago

  /orc:handoff  checkpoint state     /orc:recap  full briefing
```

Example (idle):

```
  orc  ·  skills

  ○ plan           idle                                                      —
  ○ autoresearch   idle                                                      —
  · backlog        1 open                                   1 p2
  · last commit    feat(orc-backlog): minimal TUI     ee97114 · 61 minutes ago

  /orc:pick <id>  promote from backlog     /orc:scope  shape new work
```

Design rules (matches `orc:backlog` TUI language):
- **State dot** (●/○/·) as leftmost signal: green `●` = active work, dim `○` = idle capacity, grey `·` = passive info, red `●` = failed.
- **Content bright, metadata dim.** Label column is dim; content (slug, commit subject, count) is near-white; delta/time is dim grey.
- **No frame.** Whitespace + palette do the structuring.
- **Context-aware footer hint** — suggests next move based on active state (checkpoint vs promote vs shape).
- Adaptive width (clamped 60–120), respects `NO_COLOR=1`.
