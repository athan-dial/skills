---
name: folio:prep
description: "Normalize, classify, and route materials. Runs the prep pipeline (classify -> route -> validate) and presents Human Checkpoint 1 + routing checkpoint."
trigger: /folio:prep
---

# folio:prep — Prep and Normalization

Normalize, classify, and route materials through the prep pipeline, then present Human Checkpoint 1 and the routing checkpoint.

## Entry Conditions

- Workspace exists with canonical layout.
- `intent.json` exists at workspace root.

Validate entry by checking these files exist. If missing, direct user to run `folio:init` first.

## Protocol

### 1. Inventory and Synthesize Canonical Inputs

Scan `inputs/raw_materials/` and synthesize structured versions:

- **`inputs/idea.md`** — Core contribution, research questions, key claims, novelty framing.
- **`inputs/experimental_log.md`** — Experiments, parameters, results. For white paper mode, this may be minimal — still create the file; use `<!-- GAP -->` where appropriate.
- **`inputs/materials_manifest.json`** — Per-file inventory: path, type, description, relevance, gaps.
- **`inputs/venue_profile.md`** — Venue, page limits, format, audience, evaluation criteria.
- **`inputs/figures_manifest.json`** — Existing and planned figures/tables: paths, descriptions, regeneration needs.

For incomplete synthesis, mark gaps with `<!-- GAP: description -->`. Only ask the user for gaps that block the next gate.

### 2. Run Prep Pipeline

Execute in order:

```bash
python ../../scripts/prep_materials.py workspace/
python ../../scripts/classify_materials.py workspace/
python ../../scripts/route_mode.py workspace/
python ../../scripts/validate_inputs.py workspace/
```

- `prep_materials.py` — Refreshes inventory signals.
- `classify_materials.py` — Writes `inputs/materials_passport.json`. See `../../templates/manifests/materials_passport.schema.json`.
- `route_mode.py` — Writes `route.json`: `selected_mode`, `confidence`, `reasons`, optional `user_override`. See `../../templates/manifests/route.schema.json`.
- `validate_inputs.py` — Gate A. Errors block; warnings are acceptable.

### 3. Human Checkpoint 1

Present to the user:
- What was synthesized vs. copied verbatim.
- Gaps and assumptions.
- Ask: do normalized inputs match the project? Are critical materials missing?

**Wait for explicit approval before the routing checkpoint.**

### 4. Routing Checkpoint

After Checkpoint 1 approval:

1. Read `route.json` and present: `Recommended mode: <mode> (confidence: X.XX). Reasons: [bullets].`
2. Ask: **Override?** If user chooses a different mode, set `user_override` in `route.json`.
3. **Do not proceed** until the user confirms routing.
4. Log the decision in `logs/checkpoints.md`.

## Exit Conditions

- Canonical input artifacts exist under `inputs/`.
- `materials_passport.json` and `route.json` updated.
- `validate_inputs.py` exits 0.
- Human Checkpoint 1 approved.
- Routing confirmed by user.

## Next Stage

Proceed to `folio:plan`.
