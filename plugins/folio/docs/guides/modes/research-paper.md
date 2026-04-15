# Research Paper Mode

Research paper mode is the evidence-forward pipeline for traditional research manuscripts. It produces a LaTeX draft with a verified BibTeX bibliography, a figures and tables pipeline, and a structured finalize-and-package stage for venue submission.

---

## When to use

Choose research paper mode when your materials include:

- Experimental results, benchmarks, ablation studies, or statistical analyses
- Datasets and code
- A target venue with specific LaTeX formatting requirements
- A hypothesis-driven narrative that requires traceable quantitative claims

`route_mode.py` recommends this mode when materials show strong empirical signals: experimental logs, datasets, notebooks, or benchmark output. If routing is ambiguous, override at the routing checkpoint.

---

## Stage D2: Global Planning

**Entry condition:** Checkpoint 1 and routing approved; canonical inputs available.

Folio reads your canonical inputs and generates five planning artifacts:

| Artifact | Description |
|----------|-------------|
| `planning/outline.json` | Working title, sections with ids, purposes, key points, length estimates, figure and citation dependencies, narrative arc |
| `planning/claim_ledger.json` | Claims with `id`, `statement`, `type`, `evidence_source`, `support_level`, figure/citation dependencies, notes |
| `planning/figure_plan.json` | Per-figure: id, description, type, source (`existing` / `generate` / `collect`), supported claims, caption draft |
| `planning/literature_plan.json` | Search queries, known references, coverage areas with minimum ref counts |
| `planning/results_inventory.json` | Results entries: id, description, value, source file, supported claims, verified flag |

**Gate B — Plan completeness:**
- Outline includes standard sections for the venue type
- Every claim has a `support_level`; every `unsupported` claim is explicitly flagged
- Figure plan covers all outline-referenced figures
- Literature plan covers all citation needs

**Human Checkpoint 2:** Folio presents the outline, narrative arc, claim ledger summary (highlighting weak/unsupported claims), figure plan, and literature plan. **Explicit approval required before Stage D3.**

---

## Stage D3: Support Artifact Generation

Three substages run in parallel (all must complete before drafting):

### 3A — Evidence accounting

Folio re-reads `experimental_log.md` and `results_inventory.json`, verifies each claim in `claim_ledger.json`, and updates `support_level` and notes.

**Gate C — Evidence integrity:** Blocks if any claim remains `unsupported` without user acknowledgment, or if numerical claims lack traceable sources.

### 3B — Literature discovery and verification

Folio searches using `literature_plan.json` queries (Semantic Scholar, Google Scholar, arXiv, PubMed as available), verifies each candidate via DOI or search, deduplicates, and produces:

- `citations/citation_pool.json` — Verified metadata with relevance scores
- `citations/refs.bib` — BibTeX bibliography built from verified citations only

**Gate D — Citation integrity:** Blocks on unverified pool entries or duplicate BibTeX keys. No fabricated citations enter the manuscript.

### 3C — Figure and table pipeline

Folio processes each `figure_plan.json` entry:

- `existing` — Verifies file; copies to `figures/supplied/`
- `generate` — Produces asset under `figures/generated/`
- `collect` — Flags for user provision

Produces:
- `figures/captions.json` — Figure id, path, caption, existence flag
- `tables/generated/` — LaTeX table snippets as needed

**Gate E — Artifact integrity:** Blocks if any outline-referenced figure or table is missing and not explicitly deferred; blocks if required captions are missing.

---

## Stage D4: Draft Composition

**Entry condition:** Stage D3 complete; Gates C, D, E pass.

Folio composes `drafts/paper.tex` section by section:

- Uses `\cite{key}` only for keys in `refs.bib`
- `\ref{}` labels consistent with `captions.json` and figure plan
- Quantitative claims grounded in claim ledger; `weak` support claims use softened language
- Uses `inputs/template.tex` as skeleton if present; otherwise standard article class

**Gate F — Structural integrity:**

```bash
cd plugins/folio && python scripts/check_artifacts.py workspace/
```

Broken cites and refs must be resolved before proceeding.

!!! warning "Forbidden in draft"
    Invented citations, unverifiable numbers, missing figures, and venue constraint violations all block Gate F.

---

## Stage D5: Review and Repair

**IP scan (required):**

```bash
cd plugins/folio && python scripts/scan_redlines.py workspace/
```

**IP Gate:** Violations block completion of review until addressed.

Folio runs a review pass writing `reviews/review_round_1.md` (argument flow, claim support, citations, figures/tables, clarity, venue fit, line-level suggestions) and `reviews/scorecard.json` with six numeric dimensions:

- `argument_coherence`
- `evidence_support`
- `citation_quality`
- `writing_clarity`
- `venue_fit`
- `overall`

**Gate G — Non-regression:** If `overall` drops after a repair round, Folio reverts to the pre-revision draft. Maximum 3 rounds; best-scoring draft is retained.

---

## Stage D6: Finalize

**Human Checkpoint 3:** Folio presents the final scorecard, deferred issues, and softened claims. **Explicit approval required.**

After approval:

1. Accepted draft copied to `final/paper.tex`; `final/refs.bib`; figures to `final/figures/`; tables to `final/tables/`

2. Compile:

```bash
cd plugins/folio && bash scripts/compile_package.sh workspace/
```

3. On compile failure: Folio reports errors, attempts minimal fixes, re-runs. If still failing, delivers the source bundle without PDF and documents why.

4. `logs/run_log.md` updated.

**Exit:** Submission-ready package in `final/` or documented partial export.

---

## Artifacts produced

| Artifact | Stage | Description |
|----------|-------|-------------|
| `planning/outline.json` | D2 | Section structure and narrative arc |
| `planning/claim_ledger.json` | D2 / D3 | Claims with evidence and support levels |
| `planning/figure_plan.json` | D2 | Figure sourcing and caption drafts |
| `planning/literature_plan.json` | D2 | Search queries and coverage areas |
| `planning/results_inventory.json` | D2 | Verified results mapped to claims |
| `citations/citation_pool.json` | D3 | Verified citation metadata |
| `citations/refs.bib` | D3 | BibTeX bibliography |
| `figures/captions.json` | D3 | Figure paths and captions |
| `figures/generated/` | D3 | Generated figure assets |
| `figures/supplied/` | D3 | User-supplied figure assets |
| `tables/generated/` | D3 | LaTeX table snippets |
| `drafts/paper.tex` | D4 | Working LaTeX draft |
| `reviews/ip_safety_report.md` | D5 | IP scan results |
| `reviews/review_round_N.md` | D5 | Review notes per round |
| `reviews/scorecard.json` | D5 | Quality scores |
| `final/paper.tex` | D6 | Accepted final manuscript |
| `final/paper.pdf` | D6 | Compiled PDF (if pdflatex available) |
| `final/refs.bib` | D6 | Final bibliography |

See [Artifacts](../../reference/artifacts.md) for the complete cross-mode artifact list.
