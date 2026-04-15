---
name: folio:init
description: "Initialize a Folio workspace with directory structure, intent capture, and material import. Use when starting a new manuscript project."
trigger: /folio:init
---

# folio:init — Initialize Workspace

Set up a new Folio workspace with canonical directory structure, intent capture, and material import.

## Entry Conditions

None — this is the first stage in the pipeline.

## Inputs

- `idea` — Core contribution or topic (prompt if not provided).
- `materials_path` — Folder of notes, data, figures, PDFs, etc. (prompt if not provided; accept `none` for blank slate).
- `venue` (optional) — Target outlet and formatting constraints.

## Protocol

1. **Collect missing inputs.** Prompt for `idea`, `materials_path`, and optionally `venue`.

2. **Capture intent fields.** Prompt the user for each field that populates `intent.json`:
   - `audience` — Who must understand the output.
   - `doc_type` — Short label (e.g., white paper, research article, memo).
   - `thesis` — One or two sentences: central claim or promise.
   - `constraints` — Length, tone, confidentiality, deadlines, tooling.
   - `forbidden_topics` — Topics or claims to avoid.
   - `preferred_mode` — `white_paper`, `research_paper`, `hybrid`, or `null` for auto-routing.

   Align field names and types with `../../templates/manifests/intent.schema.json`.

3. **Run initialization script:**

   ```bash
   python ../../scripts/init_workspace.py "<workspace_path>"
   ```

4. **Copy user materials** into `inputs/raw_materials/` under the workspace root. Preserve relative structure when copying trees.

5. **Write `intent.json`** at the workspace root from user responses. If `ip_policy.json` exists, ensure forbidden terms and code-name lists reflect organizational policy (see `../../templates/manifests/ip_policy.schema.json`).

6. **Append a session line** to `logs/run_log.md`.

## Exit Conditions

- Workspace directory exists with canonical layout (`inputs/`, `planning/`, `citations/`, `figures/`, `drafts/`, `reviews/`, `final/`, `exports/`, `logs/`).
- `intent.json` populated and valid for routing.
- Materials copied when provided.

## Next Stage

Proceed to `folio:prep`.
