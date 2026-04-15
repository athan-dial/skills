---
name: folio:support
description: "Evidence accounting, literature discovery, and figure/table generation. Research paper and hybrid modes only -- no-op for white paper."
trigger: /folio:support
---

# folio:support — Support Artifact Generation

Generate evidence, literature, and figure/table artifacts. Research paper and hybrid modes only.

## Entry Conditions

- Planning artifacts exist (from `folio:plan`).
- `route.json` confirms mode is `research_paper` or `hybrid`.

If mode is `white_paper`, exit immediately with: "White paper mode skips the support stage. Proceed to `folio:draft`."

If planning artifacts are missing, direct user to run `folio:plan` first.

## Protocol

Run three substages. Order is flexible; complete all before proceeding to draft.

### 3A — Evidence Accounting

1. Read `experimental_log.md` and `results_inventory.json`.
2. For each claim in `claim_ledger.json`, verify evidence; update `support_level` and notes.
3. Write updated **`planning/claim_ledger.json`**.

**Gate C — Evidence integrity:** Block if any claim remains `unsupported` without user acknowledgment, or if numerical claims lack traceable sources.

### 3B — Literature Discovery and Verification

1. Search using `literature_plan.json` queries (Semantic Scholar, arXiv, PubMed, etc.).
2. For each candidate: title, authors, year, venue, DOI/URL. **Verify** existence via DOI or search. No fabricated citations.
3. Deduplicate; rank by relevance to coverage areas.
4. Write **`citations/citation_pool.json`** — entries with `key`, metadata, `verified`, `relevance_area`, `relevance_score`.
5. Generate **`citations/refs.bib`** from verified citations only.

**Gate D — Citation integrity:** Block on unverified pool entries or duplicate BibTeX keys.

### 3C — Figure and Table Pipeline

1. For each `figure_plan.json` entry:
   - `existing` — verify file; copy to `figures/supplied/`.
   - `generate` — produce asset under `figures/generated/`.
   - `collect` — flag for user provision.
2. Write **`figures/captions.json`** — `figure_id`, `path`, `caption`, `exists`.
3. Table LaTeX snippets go to `tables/generated/` when needed.

**Gate E — Artifact integrity:** Block if any outline-referenced figure/table is missing and not explicitly deferred; block if required captions are missing.

## Exit Conditions

- `citation_pool.json` + `refs.bib` verified.
- Figures/tables exist or are explicitly deferred.
- Claim ledger finalized for support levels.
- Gates C, D, E pass.

## Next Stage

Proceed to `folio:draft`.
