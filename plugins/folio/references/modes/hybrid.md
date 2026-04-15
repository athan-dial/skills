# Hybrid Mode (H2-H6)

Selected when `route.json` returns `hybrid`. Combines executive narrative with evidence-heavy sections.

---

## H2: Conceptual Framing

Follows **W2 + W3** protocols for the conceptual front-half.

**Artifacts produced:**

- `planning/perspectives.json` (per W2)
- `planning/question_tree.json` (per W2)
- `planning/argument_graph.md` (per W3)
- `planning/claim_ledger.json` — extended claim types: `fact`, `interpretation`, `opinion`, `forecast` (per W3)

**Gate C — Claim ledger build:**

```bash
cd plugins/folio && python scripts/build_claim_ledger.py workspace/
```

Block on failure; fix JSON and claims until pass.

---

## H3: Evidence Support

Follows **D3** (substages 3A/3B/3C) for evidence-backed sections.

**Key artifacts:**

- Updated `claim_ledger.json` — merge carefully with conceptual claims from H2. Single ledger file; use claim `section` or `track` field if schema allows to distinguish conceptual vs. evidence claims.
- `citations/citation_pool.json` and `citations/refs.bib` (per D3-3B)
- Figures in `figures/`, `figures/captions.json`, `tables/generated/` as needed (per D3-3C)

**Gates C/D/E** apply per their D3 definitions.

---

## H4: Merged Outline and Draft

1. `planning/outline.json` — single outline covering both conceptual and evidence sections. Mark section `track`: `conceptual` | `evidence` in metadata if helpful.

2. **Format choice (user decides):**

   - **Option A — Split format:** Conceptual sections in `drafts/paper.md`, evidence sections in `drafts/paper.tex`, with cross-references documented in `drafts/README_hybrid.md`.
   - **Option B — Unified format:** One format only (full Markdown or full LaTeX), user decides.

3. Run `check_artifacts.py` on any LaTeX portions before review.

**Checkpoint 2:**

After merged outline (and optionally partial drafts): approve structure and format choice. **Wait for explicit approval.**

**Stitching rules when md + tex coexist:**

- Define single ordering in `outline.json` (section ids in sequence).
- For PDF compilation: either include Markdown sections as quoted blocks in a wrapper, or convert MD to LaTeX for a single build — user choice at H4.
- Always run `check_artifacts.py` on LaTeX artifact before compilation.

---

## H5: Dual Review

**IP scan (mandatory):**

```bash
cd plugins/folio && python scripts/scan_redlines.py workspace/
```

**IP Gate:** BLOCK on violations.

**Hostile review:** Conceptual parts -> `reviews/hostile_review.md`.

**Evidence review:** Data-heavy parts -> `reviews/review_round_*.md` + `reviews/scorecard.json`.

**Both gates must pass independently:**

- Conceptual quality gate (hostile review findings addressed)
- Evidence quality gate (scorecard non-regression)
- No "average failure" — fix or defer with user sign-off for each track.

**Gate G — Quality non-regression:** Same rule as other modes; max 3 rounds.

---

## H6: Combined Export

**Checkpoint 3:**

Approve packaging, sensitive content, and split vs. unified artifacts. **Wait for explicit approval.**

**Artifacts:**

- `paper.md` and/or `paper.tex` (per format choice)
- `exports/executive_summary.md`
- `exports/bd_talking_points.md`
- `citations/refs.bib`
- Figures
- `reviews/ip_safety_report.md`
- `reviews/hostile_review.md`
- Scorecards

**Compile LaTeX portions:**

```bash
cd plugins/folio && bash scripts/compile_package.sh workspace/
```

Ensure `exports/` and `final/` reflect hybrid bundle policy per `package_exports.py`. Then run shared final packaging.
