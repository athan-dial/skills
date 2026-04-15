# Research Paper Mode (D2-D6)

Selected when `route.json` returns `research_paper`. Evidence-forward pipeline with LaTeX draft, BibTeX, figures, and compilation.

---

## D2: Global Planning

**Entry:** Checkpoint 1 and routing approved; canonical inputs available.

**Required inputs:** `inputs/idea.md`, `inputs/experimental_log.md`, `inputs/venue_profile.md`, `inputs/figures_manifest.json`.

**5 planning artifacts:**

1. `planning/outline.json` — Working title; `sections` array with per-section `id`, `name`, `purpose`, `key_points`, `estimated_length`, `depends_on_figures`, `depends_on_citations`; plus `narrative_arc` string.
2. `planning/claim_ledger.json` — Claims with `id`, `statement`, `type` (quantitative/qualitative/methodological), `evidence_source`, `support_level` (`strong`|`moderate`|`weak`|`unsupported`), `depends_on_figures`, `depends_on_citations`, `notes`.
3. `planning/figure_plan.json` — Per figure: `id`, `description`, `type`, `source` (`existing`|`generate`|`collect`), `source_path`, `supports_claims`, `caption_draft`.
4. `planning/literature_plan.json` — `search_queries`, `known_references` (title, authors, relevance, bibtex key), `coverage_areas` with minimum ref counts and purpose.
5. `planning/results_inventory.json` — `results` entries: `id`, `description`, `value`, `source_file`, `supports_claims`, `verified` flag.

**Gate B — Plan completeness:**

- Outline includes standard sections for venue type.
- Every claim has `support_level`; every `unsupported` claim explicitly flagged.
- Figure plan covers figures referenced in outline.
- Literature plan covers citation needs implied by outline.

**Exit:** All 5 artifacts exist; no silent unsupported claims.

**Checkpoint 2:**

Present outline, narrative arc, claim ledger summary (highlight weak/unsupported), figure and literature plans. Ask whether story, figures, and literature align with intent. **Wait for explicit approval.**

---

## D3: Support Artifact Generation

**Entry:** Checkpoint 2 approved.

Three substages (order flexible; complete all before D4):

### 3A — Evidence Accounting

1. Read `experimental_log.md` and `results_inventory.json`.
2. For each claim in `claim_ledger.json`, verify evidence; update `support_level` and notes.
3. Write updated `planning/claim_ledger.json`.

**Gate C — Evidence integrity:** Block if any claim remains `unsupported` without user acknowledgment, or if numerical claims lack traceable sources.

### 3B — Literature Discovery and Verification

1. Search using `literature_plan.json` queries (Semantic Scholar, Google Scholar, arXiv, PubMed).
2. For each candidate: title, authors, year, venue, DOI/URL. **Verify** existence (DOI or search). No fabricated citations.
3. Deduplicate; rank by relevance to coverage areas.
4. Write `citations/citation_pool.json` — entries with `key`, metadata, `verified`, `relevance_area`, `relevance_score`.
5. Generate `citations/refs.bib` from **verified** citations only.

**Gate D — Citation integrity:** Block on unverified pool entries or duplicate BibTeX keys.

### 3C — Figure and Table Pipeline

1. For each `figure_plan.json` entry:
   - `existing` — verify file; copy to `figures/supplied/`.
   - `generate` — produce under `figures/generated/`.
   - `collect` — flag for user provision.
2. Write `figures/captions.json` — `figure_id`, `path`, `caption`, `exists`.
3. Table LaTeX snippets go to `tables/generated/`.

**Gate E — Artifact integrity:** Block if outline-referenced figure/table is missing and not explicitly deferred; block if required captions missing.

**Exit:** `citation_pool.json` + `refs.bib` verified; figures/tables exist or deferred; claim ledger final; Gates C/D/E pass.

---

## D4: Draft Composition

**Entry:** D3 complete; Gates C/D/E pass.

**Inputs:** `outline.json`, `claim_ledger.json`, `citation_pool.json`, `refs.bib`, `captions.json`, `venue_profile.md`.

**Protocol:**

1. If `inputs/template.tex` exists, use as skeleton; else standard article class.
2. Compose `drafts/paper.tex` section by section:
   - `\cite{key}` only for keys in `refs.bib`
   - `\ref{}`/labels consistent with `captions.json` and figure plan
   - Ground quantitative claims in claim ledger; soften language for `weak` support
   - Optional section files under `drafts/sections/`

**Forbidden:** Invented citations; unverifiable numbers; missing figures; ignoring venue constraints.

**Gate F — Structural integrity:**

```bash
python scripts/check_artifacts.py workspace/
```

Resolve broken cites/refs per script output.

**Exit:** `drafts/paper.tex` exists; `check_artifacts` passes.

---

## D5: Review and Repair

**Entry:** Draft exists; Gate F passed.

**IP scan (mandatory):**

```bash
python scripts/scan_redlines.py workspace/
```

**IP Gate:** BLOCK on violations until addressed.

**Review pass:** Write `reviews/review_round_1.md` — argument flow, claim support, citations, figures/tables, clarity, venue fit, line-level suggestions.

**Scorecard:** `reviews/scorecard.json` with dimensions:

- `argument_coherence`
- `evidence_support`
- `citation_quality`
- `writing_clarity`
- `venue_fit`
- `overall` (numeric, same scale each round)
- `blocking_issues` (string list; empty when clear)
- `suggestions`

**Repair:** If blocking issues, save revised draft.

**Gate G — Quality non-regression:** If `overall` drops after repair, revert to pre-revision version. Max 3 rounds; keep best-scoring draft.

**Exit:** At least one round complete; best draft selected; blocking issues resolved or explicitly deferred by user.

---

## D6: Finalize

**Checkpoint 3:**

Present final scorecard, deferred issues, softened claims. Ask whether draft is acceptable for packaging. **Wait for explicit approval.**

**Protocol (after approval):**

1. Copy accepted draft to `final/paper.tex`; `final/refs.bib` from `citations/refs.bib`; figures to `final/figures/`; tables to `final/tables/`.
2. Compile:

```bash
bash scripts/compile_package.sh workspace/
```

3. On failure: report errors, attempt minimal fixes, re-run. If still failing, deliver source bundle without PDF and document why.
4. On success: `final/` contains tex, pdf (if built), bib, figures, tables.
5. Update `logs/run_log.md`.

**Exit:** Submission-ready package in `final/` or documented partial export. Then run shared final packaging (`package_exports.py`).
