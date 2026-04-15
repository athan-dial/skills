# Hybrid Mode

Hybrid mode combines executive narrative framing with evidence-heavy sections. It runs both the white paper conceptual pipeline and the research paper support artifact pipeline, merges them into a single draft, and applies a dual review covering both conceptual quality and evidence quality.

---

## When to use

Choose hybrid mode when your manuscript needs to:

- Open with a narrative or strategic frame, then back it up with empirical results
- Target an audience that includes both executives and technical reviewers
- Combine a positioning argument with reproducible evidence
- Produce both an executive summary and a submittable research artifact

`route_mode.py` recommends hybrid when materials include a significant mix of strategic documents and experimental/data artifacts.

---

## Stage H2: Conceptual Framing

Follows the white paper W2 and W3 protocol. Produces:

- `planning/perspectives.json` — Perspective map with source materials and relevance
- `planning/question_tree.json` — Structured questions grouped by planned section
- `planning/argument_graph.md` — Argument flow: sections → claims → dependencies
- `planning/claim_ledger.json` — Extended claim types (`fact`, `interpretation`, `opinion`, `forecast`)

**Gate C — Claim ledger validation:**

```bash
cd plugins/folio && python scripts/build_claim_ledger.py workspace/
```

---

## Stage H3: Evidence Support

Follows the research paper D3 protocol (substages 3A, 3B, 3C). Merges evidence mapping into the existing claim ledger — uses a single `claim_ledger.json` with a `section` or `track` field to distinguish conceptual from evidence claims where the schema allows.

Produces:

- Updated `planning/claim_ledger.json` (merged conceptual + evidence tracks)
- `citations/citation_pool.json` and `citations/refs.bib`
- `figures/captions.json`, `figures/generated/`, `figures/supplied/`
- `tables/generated/` as needed

Gates C, D, and E apply as in research paper mode.

---

## Stage H4: Merged Outline and Draft

Folio produces a single `planning/outline.json` covering both conceptual and evidence sections, with section `track` metadata (`conceptual` | `evidence`) where helpful.

**Drafting format — user choice at Checkpoint 2:**

- **Option A (split):** Conceptual sections in `drafts/paper.md`; evidence sections in `drafts/paper.tex`; cross-references documented in `drafts/README_hybrid.md`
- **Option B (unified):** One format only — full Markdown or full LaTeX — user decides

`check_artifacts.py` runs on any LaTeX portions before review.

**Human Checkpoint 2:** Folio presents the merged outline and, optionally, partial draft sections. You approve the structure and format choice before full drafting completes.

!!! tip "Stitching the hybrid narrative"
    When `paper.md` and `paper.tex` coexist, Folio defines a single section ordering in `outline.json`. For PDF compilation, either include Markdown sections as quoted blocks in a wrapper, or convert MD sections to LaTeX for a single build — your choice at H4.

---

## Stage H5: Dual Review

Both the conceptual and evidence tracks must pass quality gates. There is no averaging — a failure in either track blocks the stage.

**IP scan (required):**

```bash
cd plugins/folio && python scripts/scan_redlines.py workspace/
```

**IP Gate:** Violations block completion.

**Hostile review:** Conceptual parts → `reviews/hostile_review.md` (logical gaps, unsupported assertions, competitive risk, clarity)

**Evidence review:** Data-heavy parts → `reviews/review_round_N.md` and `reviews/scorecard.json` with the standard six dimensions.

**Gate G — Non-regression:** Same rule as other modes; max 3 rounds; best-scoring draft retained.

---

## Stage H6: Combined Export

**Human Checkpoint 3:** Folio presents the final scorecard, deferred issues, sensitive content, and the split-vs-unified artifact plan. **Explicit approval required.**

Artifacts assembled:

- `paper.md` and/or `paper.tex`
- `exports/executive_summary.md`
- `exports/bd_talking_points.md`
- `citations/refs.bib`
- `figures/` contents
- `reviews/ip_safety_report.md`
- `reviews/hostile_review.md`
- Scorecards

**Compile LaTeX portions:**

```bash
cd plugins/folio && bash scripts/compile_package.sh workspace/
```

Final bundle assembled by `package_exports.py` under `final/` and/or `exports/`.

---

## Artifacts produced

| Artifact | Stage | Description |
|----------|-------|-------------|
| `planning/perspectives.json` | H2 | Perspective map (conceptual track) |
| `planning/question_tree.json` | H2 | Section-linked questions |
| `planning/argument_graph.md` | H2 | Argument flow |
| `planning/claim_ledger.json` | H2 / H3 | Merged claim ledger (both tracks) |
| `citations/citation_pool.json` | H3 | Verified citation metadata |
| `citations/refs.bib` | H3 | BibTeX bibliography |
| `figures/captions.json` | H3 | Figure paths and captions |
| `planning/outline.json` | H4 | Merged section structure |
| `drafts/paper.md` | H4 | Conceptual sections (Option A) |
| `drafts/paper.tex` | H4 | Evidence sections (Option A) or full draft |
| `drafts/README_hybrid.md` | H4 | Cross-reference guide (Option A) |
| `reviews/ip_safety_report.md` | H5 | IP scan results |
| `reviews/hostile_review.md` | H5 | Conceptual hostile review |
| `reviews/review_round_N.md` | H5 | Evidence review notes |
| `reviews/scorecard.json` | H5 | Quality scores |
| `exports/executive_summary.md` | H6 | Leadership summary |
| `exports/bd_talking_points.md` | H6 | BD talking points |

See [Artifacts](../../reference/artifacts.md) for the complete cross-mode artifact list.
