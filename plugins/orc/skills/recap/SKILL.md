---
name: recap
description: >
  Session-start briefing from disk state. Synthesizes what happened last session, what's in the
  backlog, and suggests what to work on next. Designed for cold-start: paste /orc:recap as first
  message in a new session. Use when: "orc recap", "orc:recap", "what did I do last time",
  "where did I leave off", "catch me up", or at the start of any new session.
  Part of the orc system: orc:plan, orc:backlog, orc:autoresearch, orc:status, orc:recap, orc:scope, orc:handoff.
---

# Orc: Recap

Produce a 10-15 line cold-start briefing from disk state.

## What to read

1. `.orc/state.json` — last orchestration state (completed or in-progress)
2. `.orc/backlog/BACKLOG.jsonl` — open items with priorities
3. `git log --oneline -10` — recent commits
4. `var/autoresearch/*/session.json` — any autoresearch sessions (completed or running)
5. `var/autoresearch/*/REPORT.md` — completed autoresearch reports
6. `.orc/backlog/items/*.md` — scan for recently modified items (new context since last session)

## Output format

```
orc recap (2026-04-14)

Last session:
  - Completed: "Entity linking hardening" — 4 tasks, entity coverage 48% -> 51%
  - Autoresearch: api-latency — 12 iterations, reached 45ms (-35ms from baseline)
  - Committed: 3 commits on main (entity linking normalizers + org prefix fallback)

Backlog (3 open):
  001 [p1] Add Redis cache layer
  002 [p1] Multi-target brief runner
  003 [p2] Shadow mode auto-apply

Suggested next:
  orc:pick 001 — Redis cache layer addresses the top latency bottleneck
```

## Behavior

- If `.orc/` doesn't exist, say so and suggest `orc:add` to start capturing ideas.
- If backlog is empty, focus on git log + autoresearch state.
- The "suggested next" should be the highest-priority backlog item, with a one-line rationale from the item's "Why" section.
- Keep the output scannable — no walls of text.
