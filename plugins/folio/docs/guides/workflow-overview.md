# Workflow Overview

Folio runs a shared spine of stages (0–1 and final export) that are common to all modes, with mode-specific stages in between. Mode branching happens at the routing checkpoint after Stage 1.

---

## Stage map

| Stage | All modes | White paper | Research paper | Hybrid |
|-------|-----------|-------------|------------|--------|
| 0 | Initialize | | | |
| 1 | Prep + Normalize | | | |
| RC | Routing checkpoint | | | |
| 2 | | W2: Perspectives | D2: Global Planning | H2: Conceptual Framing |
| 3 | | W3: Argument Structure | D3: Support Artifacts | H3: Evidence Support |
| 4 | | W4: Outline + Draft | D4: Draft Composition | H4: Merged Draft |
| 5 | | W5: Review + IP | D5: Review + Repair | H5: Dual Review |
| 6 | | W6: Executive Outputs | D6: Finalize | H6: Combined Export |
| Exit | Package + Export | | | |

**RC** = Routing checkpoint (after Checkpoint 1 approval).

---

## Stage 0: Initialize (`/folio:init`)

Folio collects your idea, audience, thesis, constraints, venue, and preferred mode (or defers to automatic routing). It runs:

```bash
cd plugins/folio && python scripts/init_workspace.py "<workspace_path>"
```

This creates the canonical workspace layout under `workspace/` and seeds `intent.json`. Your raw materials are copied into `inputs/raw_materials/`.

**Exit condition:** `workspace/` exists with all subdirectories; `intent.json` populated.

---

## Stage 1: Prep and Normalization (`/folio:prep`)

Raw materials are scanned, classified, and normalized into structured canonical inputs:

- `inputs/idea.md` — Core contribution and research questions
- `inputs/experimental_log.md` — Experiments, results, observations
- `inputs/materials_manifest.json` — Per-file inventory with relevance signals
- `inputs/venue_profile.md` — Target outlet, format, audience, evaluation criteria
- `inputs/figures_manifest.json` — Existing and planned figures

The prep pipeline runs four scripts in order:

```bash
cd plugins/folio && python scripts/prep_materials.py workspace/
cd plugins/folio && python scripts/classify_materials.py workspace/
cd plugins/folio && python scripts/route_mode.py workspace/
cd plugins/folio && python scripts/validate_inputs.py workspace/
```

Gaps in materials are marked with `<!-- GAP: description -->` rather than blocked. Only gaps that block the next gate require user input.

**Gate A — Input completeness:** `validate_inputs.py` must exit 0 before leaving Stage 1. Errors block; warnings are informational.

### Human Checkpoint 1

Folio presents what was synthesized, what was copied verbatim, identified gaps, and the mode recommendation. **Explicit approval required before routing.**

---

## Routing checkpoint

After Checkpoint 1 approval, Folio reads `route.json` and presents:

```
Recommended mode: <white_paper | research_paper | hybrid> (confidence: X.XX)
Reasons: [bullet list]
```

You can accept the recommendation or override it. The selected mode is logged in `logs/checkpoints.md`. **Folio does not proceed into mode-specific stages until you confirm.**

!!! tip "Low-confidence routing"
    If `route_mode.py` reports confidence below 0.5, the materials are ambiguous. Folio will ask you to choose a mode explicitly rather than guessing.

---

## Mode-specific stages (2–5) (`/folio:plan`, `/folio:support`, `/folio:draft`, `/folio:review`)

After routing confirmation, Folio follows one of three branches. See the mode guides for full detail:

- [White Paper Mode](modes/white-paper.md) — Perspectives, argument structure, Markdown draft, executive outputs
- [Research Paper Mode](modes/research-paper.md) — Global planning, support artifacts, LaTeX draft, finalize
- [Hybrid Mode](modes/hybrid.md) — Conceptual framing + evidence support, merged draft, dual review

All three branches share the same quality gates (G: review non-regression) and the IP gate before review is considered complete.

---

## Human Checkpoint 2

Checkpoint 2 occurs after planning in research paper and hybrid modes, or at the planning approval point in white paper mode. Folio presents:

- Outline and narrative arc
- Claim ledger summary (highlights weak and unsupported claims)
- Figure and literature plans

**Explicit approval required before drafting.**

---

## IP scanning (all modes)

Before any mode marks its review stage complete, Folio runs:

```bash
cd plugins/folio && python scripts/scan_redlines.py workspace/
```

This checks all draft content against `ip_policy.json`. If violations are found, **the IP Gate blocks shipping** until you redact, rewrite, or explicitly acknowledge the risk (which is logged).

See [IP Policy](../reference/ip-policy.md) for configuration.

---

## Human Checkpoint 3

Before final packaging, Folio presents the final scorecard, deferred issues, and softened claims. **Explicit approval required before export.**

---

## Final Packaging (`/folio:export`)

After Checkpoint 3:

```bash
cd plugins/folio && python scripts/package_exports.py workspace/
```

This assembles a mode-appropriate bundle under `final/` (and/or `exports/`). Folio reports:

- Absolute workspace path
- All artifacts produced, organized by directory
- Final review score (`overall` from latest scorecard)
- Known issues and deferred items
- Recommended next steps

---

## Resuming a workspace

Re-invoke `/folio` on an existing workspace path. Folio reads `logs/checkpoints.md` to detect the last completed stage and offers to resume from the next one.

You can also run a specific stage directly with its standalone command:

```
/folio:review workspace/
```

Use `/folio:status workspace/` to see which stages are complete before jumping in.

To change mode on an existing workspace, ask Folio to update `route.json` with a `user_override` — the change is logged.

---

## Logging

Every session appends to two log files in `workspace/logs/`:

- `run_log.md` — Decisions, overrides, tool failures, user waivers
- `checkpoints.md` — Table of stage completions and human approvals

These logs enable deterministic resume and provide an audit trail for "why did we ship this draft?"

---

## Workspace layout

```
workspace/
  intent.json
  route.json
  ip_policy.json
  inputs/
    raw_materials/
    idea.md
    experimental_log.md
    venue_profile.md
    materials_manifest.json
    figures_manifest.json
  planning/
    outline.json
    claim_ledger.json
    figure_plan.json
    literature_plan.json
    results_inventory.json
    perspectives.json        (white paper / hybrid)
    question_tree.json       (white paper / hybrid)
    argument_graph.md        (white paper / hybrid)
  citations/
    citation_pool.json
    refs.bib
  figures/
    generated/
    supplied/
    captions.json
  tables/
    generated/
  drafts/
    paper.tex                (research paper / hybrid LaTeX)
    paper.md                 (white paper / hybrid Markdown)
    sections/
  reviews/
    review_round_N.md
    scorecard.json
    ip_safety_report.md
  final/
    paper.tex
    paper.pdf
    refs.bib
    figures/
  exports/
    executive_summary.md     (white paper / hybrid)
    bd_talking_points.md     (white paper / hybrid)
  logs/
    run_log.md
    checkpoints.md
```

See [Artifacts](../reference/artifacts.md) for a stage-by-stage breakdown of what each artifact is and when it is created.
