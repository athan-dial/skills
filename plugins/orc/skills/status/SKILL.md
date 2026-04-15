---
name: status
description: >
  Single-pane view of all orc system activity: active orchestration, running autoresearch loops,
  backlog count, last commit. Use when: "orc status", "orc:status", "what's running",
  "what's the state", "show me orc", or at session start to orient.
  Part of the orc system: orc:orchestrate, orc:backlog, orc:autoresearch, orc:status, orc:recap, orc:scope, orc:handoff.
---

# Orc: Status

Render as a **markdown table** in your reply. Claude Code's UI renders markdown natively — don't use Unicode boxes, ANSI escapes, or custom width math. (This corrects an earlier misstep; see feedback_status_formatting.md.)

## What to read

1. `.orc/state.json` — active orc:orchestrate orchestration (wave, task counts, agent status)
2. `var/autoresearch/*/session.json` — running autoresearch loops (iteration, metric, delta)
3. `.orc/backlog/BACKLOG.jsonl` — open items count + priority breakdown
4. `git log -1 --format="%h %s (%cr)"` — last commit for context

## Output format

```markdown
**orc** · <repo-name>

| System | Status | Detail |
|---|---|---|
| Plan | active | `taxonomy-restructure` — wave 2/3, 3 tasks running |
| Autoresearch | active | `coverage-push` — iter 14/50, 68.2% (+2.3pp) |
| Backlog | 4 open | 1 p1 · 2 p2 · 1 p3 |
| Last commit | — | `ee97114` feat(orc-backlog): minimal TUI · 5m ago |

→ `/orc:handoff` checkpoint · `/orc:recap` full briefing
```

### Status column conventions

- **active** (bold) — work in flight
- **idle** (plain) — system is present but nothing running
- **N open** — backlog count
- **failed** (bold) — needs attention
- `—` (em-dash) — not applicable (e.g., no active work for commits)

### Footer hints (context-aware)

- Work in flight → `/orc:handoff` checkpoint · `/orc:recap` full briefing
- Idle with backlog → `/orc:pick <id>` promote · `/orc:scope` shape new work
- Totally idle → `/orc:scope` shape new work · `/orc:add <idea>` capture for later

### Empty / absent states

- No `.orc/` directory → `Backlog is not initialized. Capture an idea with \`/orc add <idea>\`.`
- No git history → omit the Last commit row entirely

## Design principle

Markdown tables are theme-aware, alignment-handled, copy-friendly. Reserve custom ANSI TUI
(like `poll-wave.sh`) for **live-updating** regions where markdown can't animate. For a
one-shot dashboard, markdown is always the right answer.
