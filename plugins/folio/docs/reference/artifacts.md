# Artifacts Reference

This page lists every artifact Folio produces, organized by stage. Mode columns indicate which modes produce each artifact: **WP** = white paper, **DP** = research paper, **HY** = hybrid.

---

## Stage 0: Initialize

| Artifact | Modes | Description |
|----------|-------|-------------|
| `workspace/` (directory tree) | All | Full canonical workspace layout created by `init_workspace.py` |
| `intent.json` | All | Declared goals, audience, thesis, constraints, forbidden topics, preferred mode |
| `logs/run_log.md` | All | Session history; timestamped by `init_workspace.py` |

---

## Stage 1: Prep and Normalization

| Artifact | Modes | Description |
|----------|-------|-------------|
| `inputs/idea.md` | All | Core contribution, research questions, key claims, novelty framing |
| `inputs/experimental_log.md` | All | Experiments, parameters, results summary, observations. Minimal or N/A for white paper |
| `inputs/materials_manifest.json` | All | Per-file inventory of raw materials: path, type, description, relevance, gaps |
| `inputs/venue_profile.md` | All | Target outlet, page limits, format, audience, evaluation criteria |
| `inputs/figures_manifest.json` | All | Existing and planned figures/tables with paths, descriptions, regeneration needs |
| `inputs/materials_passport.json` | All | Per-material provenance, classification, and allowed-use policy (from `classify_materials.py`) |
| `route.json` | All | Recommended mode, confidence score, reasons, user override (from `route_mode.py`) |

---

## Routing Checkpoint

| Artifact | Modes | Description |
|----------|-------|-------------|
| `logs/checkpoints.md` | All | Routing decision logged: stage id, mode, timestamp, status |

---

## Stage 2: Planning / Framing

### White paper (W2–W3)

| Artifact | Description |
|----------|-------------|
| `planning/perspectives.json` | Array of perspectives: id, viewpoint, key arguments, source materials, relevance |
| `planning/question_tree.json` | Structured questions grouped by planned section |
| `planning/argument_graph.md` | Argument flow as text/ASCII: sections → claims → dependencies |
| `planning/claim_ledger.json` | Claims with extended types (fact, interpretation, opinion, forecast), perspective links |

### Research paper (D2)

| Artifact | Description |
|----------|-------------|
| `planning/outline.json` | Working title, sections with ids, purposes, key points, length estimates, narrative arc |
| `planning/claim_ledger.json` | Claims with quantitative/qualitative/methodological types, evidence sources, support levels |
| `planning/figure_plan.json` | Per-figure: id, description, type, source, supported claims, caption draft |
| `planning/literature_plan.json` | Search queries, known references, coverage areas with minimum ref counts |
| `planning/results_inventory.json` | Results entries: id, description, value, source file, supported claims, verified flag |

### Hybrid (H2)

| Artifact | Description |
|----------|-------------|
| `planning/perspectives.json` | Perspective map (conceptual track) |
| `planning/question_tree.json` | Section-linked question structure |
| `planning/argument_graph.md` | Argument flow (conceptual track) |
| `planning/claim_ledger.json` | Extended claim types (conceptual track; merged with evidence track in H3) |

---

## Stage 3: Support Artifacts

### Research paper (D3) and Hybrid (H3)

| Artifact | Stage | Description |
|----------|-------|-------------|
| `planning/claim_ledger.json` (updated) | D3-3A / H3 | Claim ledger updated with verified evidence mapping |
| `citations/citation_pool.json` | D3-3B / H3 | Verified citation metadata: key, title, authors, year, venue, DOI, verified flag, relevance |
| `citations/refs.bib` | D3-3B / H3 | BibTeX bibliography built from verified citations only |
| `figures/supplied/` | D3-3C / H3 | Existing figures copied from raw materials |
| `figures/generated/` | D3-3C / H3 | Figures produced during the workflow |
| `figures/captions.json` | D3-3C / H3 | Figure id, path, caption, existence flag |
| `tables/generated/` | D3-3C / H3 | LaTeX table snippets |

---

## Stage 4: Draft Composition

### White paper (W4)

| Artifact | Description |
|----------|-------------|
| `planning/outline.json` | Section structure with ids, purposes, key points |
| `drafts/paper.md` | Working Markdown draft |
| `drafts/reference_list.md` | Parallel reference list if full `refs.bib` not yet built (optional) |
| `drafts/sections/` | Optional section splits for long works |

### Research paper (D4)

| Artifact | Description |
|----------|-------------|
| `drafts/paper.tex` | Working LaTeX draft |
| `drafts/sections/` | Optional section intermediates |

### Hybrid (H4)

| Artifact | Description |
|----------|-------------|
| `planning/outline.json` | Merged section structure (conceptual + evidence tracks) |
| `drafts/paper.md` | Conceptual sections (Option A) or full draft (Option B) |
| `drafts/paper.tex` | Evidence sections (Option A) or full LaTeX draft (Option B) |
| `drafts/README_hybrid.md` | Cross-reference guide explaining how sections stitch (Option A only) |

---

## Stage 5: Review

### All modes

| Artifact | Modes | Description |
|----------|-------|-------------|
| `reviews/ip_safety_report.md` | All | IP/redline scan results: file paths, line numbers, matched patterns |
| `reviews/review_round_N.md` | All | Review notes per round (argument flow, claim support, clarity, venue fit) |
| `reviews/scorecard.json` | All | Quality scores: argument_coherence, evidence_support, citation_quality, writing_clarity, venue_fit, overall |

### White paper additional (W5)

| Artifact | Description |
|----------|-------------|
| `reviews/hostile_review.md` | External critic review: logical gaps, unsupported assertions, competitive risk |

### Hybrid additional (H5)

| Artifact | Description |
|----------|-------------|
| `reviews/hostile_review.md` | Hostile review of conceptual sections |

---

## Stage 6: Finalize / Executive Outputs

### White paper (W6)

| Artifact | Description |
|----------|-------------|
| `exports/executive_summary.md` | ~1 page for leadership: thesis, why it matters, risks, asks |
| `exports/bd_talking_points.md` | Bullets for BD conversations: pain, differentiation, proof, objections |

### Research paper (D6)

| Artifact | Description |
|----------|-------------|
| `final/paper.tex` | Accepted final LaTeX manuscript |
| `final/refs.bib` | Final bibliography |
| `final/figures/` | Final figure assets |
| `final/tables/` | Final table files |
| `final/paper.pdf` | Compiled PDF (if `pdflatex` available) |

### Hybrid (H6)

| Artifact | Description |
|----------|-------------|
| `final/paper.tex` and/or `final/paper.md` | Final manuscript (format per H4 choice) |
| `final/refs.bib` | Final bibliography |
| `final/figures/` | Final figure assets |
| `exports/executive_summary.md` | Leadership summary |
| `exports/bd_talking_points.md` | BD talking points |
| `final/paper.pdf` | Compiled PDF for LaTeX portions (if `pdflatex` available) |

---

## Final Packaging (all modes)

| Artifact | Modes | Description |
|----------|-------|-------------|
| `final/` (assembled bundle) | All | Mode-appropriate final package assembled by `package_exports.py` |
| `final/submission_bundle.zip` | All | Zip of final deliverables (if produced by `package_exports.py`) |

---

## Logs (all modes, all stages)

| Artifact | Description |
|----------|-------------|
| `logs/run_log.md` | Session history: decisions, overrides, tool failures, user waivers |
| `logs/checkpoints.md` | Table of stage completions and human approvals: stage id, mode, timestamp, pass/fail |
