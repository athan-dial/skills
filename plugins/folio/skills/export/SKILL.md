---
name: folio:export
description: "Human Checkpoint 3, finalize artifacts, compile LaTeX (if applicable), and package exports for delivery."
trigger: /folio:export
---

# folio:export — Finalize and Package

Present Human Checkpoint 3, finalize artifacts, compile LaTeX if applicable, and package the export bundle.

## Entry Conditions

- Review stage complete (at least one review round; Gate G passed).
- Read `route.json` for effective mode.

If review is incomplete, direct user to run `folio:review` first.

## Protocol

### 1. Human Checkpoint 3 (All Modes)

Present to the user:
- Final scorecard (or N/A for scoreless paths with user sign-off).
- Deferred issues and softened claims.
- For white paper/hybrid: confirm BD/summary tone and sensitive claims.

**Wait for explicit approval before packaging.**

### 2. Mode-Specific Finalization

#### White Paper (W6)

- Write **`exports/executive_summary.md`** — ~1 page: thesis, why it matters, risks, asks.
- Write **`exports/bd_talking_points.md`** — Bullets: customer pain, differentiation, proof, objections.

#### Research Paper (D6)

- Copy accepted draft to **`final/paper.tex`**.
- Copy `citations/refs.bib` to **`final/refs.bib`**.
- Copy figures to **`final/figures/`**, tables to **`final/tables/`**.

#### Hybrid (H6)

- All of white paper outputs (`executive_summary.md`, `bd_talking_points.md`).
- All of research paper outputs where LaTeX portions exist.

### 3. Compile (Research Paper + Hybrid with LaTeX)

```bash
bash ../../scripts/compile_package.sh workspace/
```

On failure: report errors, attempt minimal fixes, re-run. If still failing, deliver source bundle without PDF and document why.

### 4. Package Exports (All Modes)

```bash
python ../../scripts/package_exports.py workspace/
```

Read script stdout for the output directory. Confirm listing for the user.

### 5. Update Logs

Append final entry to `logs/run_log.md` and `logs/checkpoints.md`.

## Exit Conditions

- Submission-ready package in `final/` and/or `exports/`.
- All mode-appropriate artifacts present.
- Logs updated.

## Final Report

Report to the user:
- Absolute workspace path.
- Artifacts produced (inputs, planning, citations, figures, drafts, reviews, exports).
- Final review score.
- Known issues and deferred items.
- Next steps (proofread, legal review, submission, iteration).
