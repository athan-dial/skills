# White Paper Mode

White paper mode is for conceptual, executive, and strategic manuscripts where narrative clarity and argument structure matter more than primary data novelty. The draft is Markdown-first; the export includes executive-oriented deliverables.

---

## When to use

Choose white paper mode when your materials are primarily:

- Strategic analysis, internal research notes, or position documents
- Literature synthesis without original experimental data
- Thought leadership or industry perspective pieces
- Executive briefings or policy papers

`route_mode.py` recommends this mode automatically when materials lack strong empirical signals (experimental logs, datasets, statistical results). If routing is ambiguous, you can override at the routing checkpoint.

---

## Stage W2: Perspective Discovery

**Goal:** Map the viewpoint landscape before locking argument structure.

Folio scans your raw materials, `idea.md`, and available external literature to identify distinct perspectives. It produces:

- `planning/perspectives.json` — Array of perspectives with `perspective_id`, viewpoint, key arguments, source materials, and relevance
- `planning/question_tree.json` — Structured questions the paper must answer, grouped by planned section

**Exit condition:** At least three distinct perspectives identified, or user waiver recorded in `logs/run_log.md`.

---

## Stage W3: Argument Structure

**Goal:** Thesis, counterthesis, and claim ledger aligned to perspectives.

Folio formulates the thesis and strongest counterthesis, then maps claims to perspectives. It produces:

- `planning/argument_graph.md` — Argument flow as text/ASCII: sections → claims → dependencies
- `planning/claim_ledger.json` — Claims with extended types: `fact`, `interpretation`, `opinion`, `forecast`

**Gate C — Claim ledger validation:**

```bash
cd plugins/folio && python scripts/build_claim_ledger.py workspace/
```

Folio blocks on failure and fixes JSON and claims until this passes.

!!! tip "White paper vs. research paper claim types"
    White paper mode uses extended claim types (`fact`, `interpretation`, `opinion`, `forecast`). Research paper mode uses `quantitative`, `qualitative`, `methodological`. Hybrid mode supports both sets.

---

## Stage W4: Outline and Section Drafting

**Goal:** Markdown-first draft for executive readability.

Folio generates `planning/outline.json` and drafts `drafts/paper.md`. Key constraints:

- Draft is Markdown, **not** LaTeX
- Citations use `[Author, Year]` style; a parallel `drafts/reference_list.md` tracks references if `refs.bib` is not yet built
- Every non-trivial claim must trace to `claim_ledger.json`
- Internal code names and unexplained jargon are forbidden (also enforced by IP scan)

Optional: long works can split sections under `drafts/sections/`.

**Gate:** All `question_tree.json` questions are covered by outline sections; every non-trivial claim traces to the ledger.

---

## Stage W5: Review

**IP scan (required):**

```bash
cd plugins/folio && python scripts/scan_redlines.py workspace/
```

Writes `reviews/ip_safety_report.md`. **IP Gate:** Violations block completion until cleared, redacted, or explicitly acknowledged.

**Hostile review:** Folio reads `drafts/paper.md` as an external critic and writes `reviews/hostile_review.md` covering logical gaps, unsupported assertions, competitive risk, clarity, and factual risk.

**Standard review:** Folio writes `reviews/review_round_1.md` and `reviews/scorecard.json` with numeric subscores for coherence, support, citations/clarity, and venue fit.

**Gate G — Non-regression:** If the `overall` score drops after a repair round, Folio reverts to the better draft. Maximum 3 review rounds; best-scoring artifact is retained with residual issues documented.

---

## Stage W6: Executive Outputs

Folio produces export-ready deliverables:

- `exports/executive_summary.md` — ~1 page for leadership: thesis, why it matters, risks, asks
- `exports/bd_talking_points.md` — Bullets for business development conversations: customer pain, differentiation, proof, objections

**Human Checkpoint 3:** Folio asks you to confirm BD/summary tone, sensitive claims, and any deferrals before packaging.

---

## Artifacts produced

| Artifact | Stage | Description |
|----------|-------|-------------|
| `planning/perspectives.json` | W2 | Perspective map |
| `planning/question_tree.json` | W2 | Section-linked question structure |
| `planning/argument_graph.md` | W3 | Argument flow diagram |
| `planning/claim_ledger.json` | W3 | Claims with types and perspective links |
| `planning/outline.json` | W4 | Section structure |
| `drafts/paper.md` | W4 | Working Markdown draft |
| `reviews/ip_safety_report.md` | W5 | IP scan results |
| `reviews/hostile_review.md` | W5 | External critic review |
| `reviews/review_round_N.md` | W5 | Standard review notes |
| `reviews/scorecard.json` | W5 | Quality scores |
| `exports/executive_summary.md` | W6 | Leadership summary |
| `exports/bd_talking_points.md` | W6 | BD conversation bullets |

See [Artifacts](../../reference/artifacts.md) for the complete cross-mode artifact list.

---

## What white paper mode does not do

- Does not produce a LaTeX draft (use [Research Paper](research-paper.md) or [Hybrid](hybrid.md) for LaTeX output)
- Does not run a literature search and citation verification pipeline (only citation-style references in prose)
- Does not generate figures from data sources (figures from raw materials can be referenced; new figures must be provided)
