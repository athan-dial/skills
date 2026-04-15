---
name: orc:backlog
description: >
  Lightweight backlog for the orc system. Capture ideas with rich context mid-session,
  triage later, promote to orc:plan tasks. Lives at .orc/backlog/ in the repo.
  Use when: "add to backlog", "orc add", "orc:add", "backlog this", "save this idea",
  "park this for later", "orc list", "orc:list", "orc triage", "orc:triage",
  "orc pick", "orc:pick", "what's in the backlog", "show me the backlog",
  or when the user ideates something worth capturing for a future session.
  Part of the orc system: orc:plan, orc:backlog, orc:autoresearch, orc:status, orc:recap, orc:scope, orc:handoff.
---

# Orc: Backlog

Capture ideas mid-session with rich context. Triage and promote to `/orchestrate` later.

## Commands

- `/orc add [idea]` — Capture an idea with context from current session
- `/orc list` — Show backlog summary table (id, title, priority, tags, age)
- `/orc triage` — Interactive: review items, re-prioritize, archive stale ones
- `/orc pick [id]` — Load an item's full context and promote to `/orchestrate`
- `/orc drop [id]` — Archive an item (moves to `.orc/backlog/archive/`)

## Storage: `.orc/backlog/`

```
.orc/
├── backlog/
│   ├── BACKLOG.jsonl       # Index: one JSON line per item
│   ├── items/
│   │   ├── 001-cache-layer.md
│   │   ├── 002-multi-target-brief.md
│   │   └── 003-org-ror-seed.md
│   └── archive/            # Dropped/completed items
└── state.json              # Active orchestration state (from /orchestrate-handoff)
```

Add `.orc/` to `.gitignore` unless the user wants it tracked.

## /orc add [idea]

Capture flow (zero questions — Claude infers everything):

1. Parse the idea from args or recent conversation context
2. Auto-assign next sequential ID from BACKLOG.jsonl
3. Write rich item markdown (see template below)
4. Append index line to BACKLOG.jsonl
5. Confirm with one-line summary

### BACKLOG.jsonl format

```json
{"id": "003", "title": "Seed org synonyms from ROR", "priority": "p2", "tags": ["catalog", "org-er"], "created": "2026-04-14", "status": "open"}
```

### Item markdown template

```markdown
# <Title>

**Priority**: p1/p2/p3
**Tags**: [tag1, tag2]
**Created**: YYYY-MM-DD
**Origin**: <what was being worked on when this idea emerged>

## Why

<1-3 sentences: what problem this solves, why it matters now>

## Context snapshot

<State of the world when captured: relevant metrics, recent changes, what triggered the idea>

## Files involved

- `path/to/file.py` — <why relevant>
- `path/to/other.py` — <why relevant>

## Suggested first step

<Concrete action to start: a command to run, a file to read, a research question to answer>

## Estimated scope

<Trivial / Focused / Substantial / Epic>
<If known: which executor — Claude direct / Cursor / Codex>
```

### Priority assignment

- **p1**: Directly unblocks current work or a known bottleneck
- **p2**: High leverage but not urgent — next logical step after current work
- **p3**: Good idea, no urgency — explore when bandwidth allows

Claude assigns priority based on conversation context. User can override during triage.

## /orc list

Read BACKLOG.jsonl, display:

```
.orc backlog (3 items)
  001  p1  Add Redis cache layer          [performance, infra]     2d ago
  002  p2  Migrate auth to OAuth2              [auth, security]   2d ago
  003  p2  Seed org synonyms from ROR             [catalog, org-er]        2d ago
```

## /orc triage

Interactive review of open items:

1. Display the list
2. For each item (or user-selected subset), ask: keep/reprioritize/drop/promote
3. **Promote** = generate an `/orchestrate` prompt from the item's context and copy to clipboard
4. **Drop** = move to archive with reason

## /orc pick [id]

The bridge to `/orchestrate`:

1. Read the item's full markdown
2. Read current codebase state relevant to the item's files
3. Generate a complete `/orchestrate` prompt that includes:
   - The item's context (from the markdown)
   - Current state delta (what changed since the item was captured)
   - Suggested task decomposition
   - Executor routing recommendations
4. Present the prompt for confirmation, then either:
   - Copy to clipboard for a fresh session
   - Or directly invoke `/orchestrate` in the current session
5. Move item to archive with `status: promoted`

## Integration with /orchestrate

- `/orchestrate` should check `.orc/backlog/` at session start and mention if items exist
- `/orchestrate-handoff` already writes to `.orc/state.json` — the backlog sits alongside it
- When `/orchestrate` completes a task that matches a backlog item, auto-archive it

## Design principles

- **Zero friction capture**: `/orc add` should take <5 seconds. Claude infers everything.
- **Rich context, lean index**: BACKLOG.jsonl is the fast scan; item markdown is the deep context.
- **No framework lock-in**: Plain markdown + JSONL. Any agent can read it. No special tooling needed.
- **Session-boundary resilient**: Everything on disk. New session reads `.orc/backlog/` and has full context.
