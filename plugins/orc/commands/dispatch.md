---
description: Execute an orc-plan/1 directory across parallel HOME-isolated agents (Cursor/Codex/Claude). Soft-refuses freeform input — prefers /orc:plan
argument-hint: '[slug, plan dir path, or freeform request]'
---

Invoke the `dispatch` skill (from the `orc` plugin) with the user's arguments: $ARGUMENTS

If no arguments are provided, prompt for: a slug under .orc/plans/, an explicit plan dir path, or a freeform description (which will trigger the soft-refuse flow recommending /orc:plan).
