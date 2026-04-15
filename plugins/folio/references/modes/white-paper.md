# White Paper Mode (W2-W6)

Selected when `route.json` returns `white_paper`. Emphasizes narrative, executive clarity, and strategic framing over primary-data novelty.

---

## W2: Perspective Discovery

**Goal:** Map viewpoints before locking argument structure.

**Protocol:**

1. Scan `inputs/raw_materials/`, `idea.md`, and available external literature (Semantic Scholar, arXiv, PubMed, etc.).
2. Write `planning/perspectives.json` — array of objects:
   - `perspective_id` (stable for later claim mapping)
   - `viewpoint`
   - `key_arguments`
   - `source_materials` (paths or IDs)
   - `relevance` — pick one scheme (`high`/`medium`/`low` or numeric) and keep it consistent
3. Write `planning/question_tree.json` — structured questions grouped by planned section.

**Quality bar:**

- At least 3 distinct perspectives, or explicit user waiver logged in `logs/run_log.md`.
- Each perspective cites at least one source material or external reference.
- Question tree nodes map to sections in the later `outline.json`.

**Exit:** Both files exist; minimum perspective count met.

---

## W3: Argument Structure

**Goal:** Thesis, counterthesis, and claim ledger aligned to perspectives.

**Protocol:**

1. Formulate thesis and strongest counterthesis in `planning/argument_graph.md` header.
2. Map claims to perspectives; plan how the ledger supports narrative sections.
3. Write `planning/argument_graph.md` — textual/ASCII argument flow (sections -> claims -> dependencies).
4. Write `planning/claim_ledger.json` with extended claim types:
   - `fact` — verifiable statement
   - `interpretation` — reasoned inference from evidence
   - `opinion` — subjective position
   - `forecast` — forward-looking prediction
   - Plus fields required by `templates/manifests/claim_ledger.schema.json`
   - Link claims to `perspective_id` where relevant

**Gate C — Claim ledger build:**

```bash
python scripts/build_claim_ledger.py workspace/
```

Block on script failure; fix JSON and claims until pass.

---

## W4: Outline and Section Drafting

**Goal:** Markdown-first draft for executive readability.

**Protocol:**

1. Generate `planning/outline.json` — same logical schema as research paper (sections with ids, purposes, key points, length estimates, figure/citation dependencies).
2. Draft `drafts/paper.md` (Markdown, not LaTeX).
3. Citation style: `[Author, Year]` in prose. Maintain parallel list in `drafts/reference_list.md` if full `refs.bib` not yet built.
4. Optional: section splits under `drafts/sections/` for long work.

**Forbidden:**

- Unexplained jargon
- Unsupported claims vs. ledger
- Internal code names (also caught by IP scan)

**Gate:** Outline sections cover `question_tree.json`; every non-trivial claim traces to `claim_ledger.json`.

---

## W5: Review

**IP scan (mandatory):**

```bash
python scripts/scan_redlines.py workspace/
```

Writes `reviews/ip_safety_report.md`. **IP Gate:** BLOCK on violations until cleared, redacted, or explicitly acknowledged.

**Hostile review:**

- Read `drafts/paper.md` as an external critic.
- Write `reviews/hostile_review.md`: logical gaps, unsupported assertions, competitive risk, clarity, factual risk.

**Standard review:**

- Write `reviews/review_round_1.md`.
- Write `reviews/scorecard.json` — numeric subscores and `overall` (coherence, support, citations/clarity, venue fit as applicable).

**Gate G — Quality non-regression:**

- On repair rounds, if `overall` drops vs. prior best, **revert** to the better draft.
- Max 3 review rounds; keep best-scoring artifact; document residual issues.

---

## W6: Executive Outputs

**Artifacts:**

1. `exports/executive_summary.md` — ~1 page for leadership: thesis, why it matters, risks, asks. Short paragraphs, no unexplained acronyms, link to detailed draft path.
2. `exports/bd_talking_points.md` — Bullets for business development: customer pain, differentiation, proof, objections. No confidential metrics unless approved in `intent.json` constraints.

**Checkpoint 3:**

Before packaging: confirm BD/summary tone, sensitive claims, and deferrals. **Wait for explicit approval.**

Then run shared final packaging (`package_exports.py`).
