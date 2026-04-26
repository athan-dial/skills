---
description: Legacy multi-agent orchestrator (freeform LLM-decompose). Prefer /orc:dispatch with /orc:plan for new flows.
argument-hint: '[plan file path or freeform request]'
---

Invoke the `orchestrate` skill (from the `orc` plugin) with the user's arguments: $ARGUMENTS

If no arguments are provided, prompt for either a plan file path or a freeform description of the work to decompose.

Note: this is the legacy 0.5.0 path. For structured plans + parallel HOME-isolated dispatch, use `/orc:plan` (interview) followed by `/orc:dispatch <slug>`.

