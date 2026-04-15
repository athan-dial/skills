---
name: orc:status
description: >
  Single-pane view of all orc system activity: active orchestration, running autoresearch loops,
  backlog count, last completed task. Use when: "orc status", "orc:status", "what's running",
  "what's the state", "show me orc", or at session start to orient.
  Part of the orc system: orc:plan, orc:backlog, orc:autoresearch, orc:status, orc:recap, orc:scope, orc:handoff.
---

# Orc: Status

Display a single-pane summary of all orc system state.

## What to read

1. `.orc/state.json` — active orc:plan orchestration (wave, task counts, agent status)
2. `var/autoresearch/*/session.json` — running autoresearch loops (iteration, metric, status)
3. `.orc/backlog/BACKLOG.jsonl` — open backlog items (count by priority)
4. `git log --oneline -3` — recent commits for context

## Output format

```
orc status
  Plan:       <none active | "slug" wave N/M, K tasks running>
  Autoresearch: <none | "slug" iter N/M, metric% (+Xpp from baseline)>
  Backlog:    N open (X p1, Y p2, Z p3)
  Last commit: <hash> <message> (<time ago>)
```

If nothing is active, suggest: "Run `orc:recap` for a full session briefing, or `orc:list` to browse the backlog."
