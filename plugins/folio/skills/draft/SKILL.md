---
name: folio:draft
description: "Compose the manuscript draft: Markdown for white paper, LaTeX for research paper, or merged format for hybrid."
trigger: /folio:draft
---

# folio:draft — Draft Composition

Compose the manuscript draft in the format appropriate to the confirmed mode.

## Entry Conditions

- `planning/outline.json` and `planning/claim_ledger.json` exist.
- For research paper and hybrid: Gates C/D/E passed (support stage complete).
- Read `route.json` for effective mode.

If prerequisites are missing, direct user to the appropriate prior stage.

## Protocol by Mode

### White Paper (W4)

1. Generate **`planning/outline.json`** if not already present (same schema as research paper).
2. Draft **`drafts/paper.md`** (Markdown, not LaTeX).
3. Use citation-style references `[Author, Year]` in prose; maintain `drafts/reference_list.md` if full `refs.bib` is not yet built.
4. **Forbidden:** unexplained jargon, unsupported claims vs. ledger, internal code names.
5. Optional: section splits under `drafts/sections/`.

**Gate:** Outline sections cover `question_tree.json`; every non-trivial claim traces to `claim_ledger.json`.

### Research Paper (D4)

1. If `inputs/template.tex` exists, use it as skeleton; else standard article class.
2. Compose **`drafts/paper.tex`** section by section:
   - `\cite{key}` only for keys in `refs.bib`.
   - `\ref{}` / labels consistent with `captions.json` and figure plan.
   - Ground quantitative claims in claim ledger; soften language for `weak` support.
   - Optional section files under `drafts/sections/`.
3. **Forbidden:** invented citations, unverifiable numbers, missing figures, ignoring venue constraints.

**Validation:**

```bash
python ../../scripts/check_artifacts.py workspace/
```

**Gate F — Structural integrity:** Resolve broken cites/refs per script output.

### Hybrid (H4)

1. Write **`planning/outline.json`** covering both conceptual and evidence sections. Mark section `track`: `conceptual` | `evidence` where helpful.
2. **Format choice** (ask user at Checkpoint 2 if not already decided):
   - **Option A:** `drafts/paper.md` (conceptual) + `drafts/paper.tex` (evidence) with `drafts/README_hybrid.md` documenting stitching.
   - **Option B:** Single format (full Markdown or full LaTeX).
3. Run `check_artifacts.py` on any LaTeX portions.

## Exit Conditions

- Draft exists: `drafts/paper.md` and/or `drafts/paper.tex`.
- Gate F passes for LaTeX content.

## Next Stage

Proceed to `folio:review`.
