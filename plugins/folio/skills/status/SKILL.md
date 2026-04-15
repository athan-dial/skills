---
name: folio:status
description: "Display pipeline state for a Folio workspace: current mode, completed stages, next step, and any blocking issues."
trigger: /folio:status
---

# folio:status — Pipeline Status

Read-only inspection of workspace state. No side effects.

## Entry Conditions

- A workspace path exists (prompt if not provided).

## Protocol

1. Read **`route.json`** for effective mode (`user_override` or `selected_mode`). If missing, report "Mode not yet determined (run folio:prep)."

2. Read **`logs/checkpoints.md`** for completed stages and checkpoint approvals.

3. Read **`logs/run_log.md`** for recent decisions, overrides, and blockers.

4. Present status summary:

   ```
   Workspace: <absolute path>
   Mode (effective): <white_paper | research_paper | hybrid | pending>
   Last completed stage: <stage id>
   Next recommended: <stage id> -- <one-line description>
   Blocking issues: <list or "none">
   ```

5. If the user has a stale or incomplete workspace, suggest the appropriate next command.

## Exit Conditions

Status displayed. No files modified.
