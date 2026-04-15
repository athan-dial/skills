---
description: Persist and resume orc orchestration state to disk — checkpoint or hand off to a fresh session
argument-hint: '[checkpoint | resume | <freeform note>]'
---

Invoke the `handoff` skill (from the `orc` plugin) with the user's arguments: $ARGUMENTS

Use ONLY when the user explicitly asks to checkpoint, hand off, or resume orchestration. Do not invoke preemptively.
