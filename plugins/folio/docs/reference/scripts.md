# Scripts Reference

All Folio helper scripts live under `scripts/`. They are invoked by the skill via the `Bash` tool — not imported as libraries. Every script accepts a workspace path as its only argument and exits non-zero on failure with a human-readable error message.

**Python scripts target 3.10+ with no external dependencies beyond stdlib.**

---

## Usage pattern

```bash
cd plugins/folio && python scripts/<script_name>.py <workspace_path>
```

```bash
cd plugins/folio && bash scripts/compile_package.sh <workspace_path>
```

All workspace paths below are relative to your chosen workspace root unless stated otherwise. Run scripts from the `skills/` repo root by prefixing commands with `cd plugins/folio && ...`.

---

## Script inventory

### `init_workspace.py`

**Purpose:** Create the canonical workspace directory tree and seed initial metadata files.

**Invoked at:** Stage 0 (Initialize)

```bash
cd plugins/folio && python scripts/init_workspace.py "<workspace_path>"
```

**Creates:**
- All workspace subdirectories (`inputs/raw_materials/`, `planning/`, `citations/`, `figures/generated/`, `figures/supplied/`, `tables/generated/`, `drafts/sections/`, `reviews/`, `final/figures/`, `final/tables/`, `logs/`, `exports/`)
- Seeds `logs/run_log.md` with a timestamped session line

**Exit codes:**
- `0` — Workspace created (or already exists with valid layout)
- Non-zero — Write permission error or invalid path

---

### `prep_materials.py`

**Purpose:** Scan `inputs/raw_materials/` and produce a file-type inventory for downstream classification.

**Invoked at:** Stage 1 (Prep), substage 1

```bash
cd plugins/folio && python scripts/prep_materials.py workspace/
```

Maps file extensions to material types (`markdown`, `text`, `pdf`, `latex`, `bibtex`, `data`, `code`, etc.) and refreshes inventory signals used by `classify_materials.py`.

**Exit codes:**
- `0` — Inventory complete
- Non-zero — Workspace path invalid or `inputs/raw_materials/` missing

---

### `classify_materials.py`

**Purpose:** Classify materials from the inventory and write `inputs/materials_passport.json`.

**Invoked at:** Stage 1 (Prep), substage 2

```bash
cd plugins/folio && python scripts/classify_materials.py workspace/
```

Assigns each material a `source_type` (`internal_data`, `public_data`, `literature`, `proprietary_doc`, `code`), `classification` (`public`, `internal`, `confidential`), and `allowed_use` policy. Uses path/filename hints (e.g., `arxiv`, `references`, `experiment`) to infer classification.

**Output:** `inputs/materials_passport.json` (schema: `templates/manifests/materials_passport.schema.json`)

**Exit codes:**
- `0` — Passport written
- Non-zero — Missing manifest input or schema validation failure

---

### `route_mode.py`

**Purpose:** Infer document mode from `intent.json` and `materials_passport.json`; write `route.json`.

**Invoked at:** Stage 1 (Prep), substage 3

```bash
cd plugins/folio && python scripts/route_mode.py workspace/
```

Scores materials for empirical signals (data files, code, notebooks, experiment-hint strings) and narrative/strategic signals to recommend `white_paper`, `research_paper`, or `hybrid`. Reports a `confidence` score between 0 and 1.

**Output:** `route.json` with `selected_mode`, `confidence`, `reasons`, and `user_override` (null by default)

**Exit codes:**
- `0` — Route written (even for low-confidence cases — low confidence is reported in `route.json`, not as a failure)
- Non-zero — Missing inputs or write error

!!! warning "Low confidence"
    Confidence below 0.5 means the materials are ambiguous. Folio will ask for an explicit mode override rather than proceeding automatically.

---

### `validate_inputs.py`

**Purpose:** Validate canonical inputs in the workspace (Gate A: Input completeness).

**Invoked at:** Stage 1 (Prep), substage 4; re-run after editing any `inputs/*` file

```bash
cd plugins/folio && python scripts/validate_inputs.py workspace/
```

Checks that required files exist (`inputs/idea.md`, `inputs/experimental_log.md`, `inputs/venue_profile.md`, `inputs/materials_manifest.json`, `inputs/figures_manifest.json`) and are not placeholder stubs (minimum ~50 characters of content).

**Exit codes:**
- `0` — All required inputs valid (warnings may still appear)
- Non-zero — Missing files or placeholder content detected (errors block Stage 1 exit)

!!! tip "When to re-run"
    Re-run `validate_inputs.py` after editing any canonical `inputs/*` file, after `classify_materials.py` or `route_mode.py` if inputs change, and always before leaving Stage 1.

---

### `build_claim_ledger.py`

**Purpose:** Validate claim ledger integrity (Gate C: Evidence integrity).

**Invoked at:** Stage W3 (white paper), Stage D3-3A (research paper), Stage H2/H3 (hybrid)

```bash
cd plugins/folio && python scripts/build_claim_ledger.py workspace/
```

Checks that:
- All claims have recognized types (`quantitative`, `qualitative`, `methodological`, `fact`, `interpretation`, `opinion`, `forecast`)
- All claims have a `support_level`
- No claims are `unsupported` without explicit user acknowledgment
- Numerical claims have traceable `evidence_source` values

**Exit codes:**
- `0` — Claim ledger valid
- Non-zero — Unrecognized types, missing support levels, or unsupported claims without acknowledgment

---

### `check_artifacts.py`

**Purpose:** Validate draft artifact references (Gates E + F: Artifact and rendering integrity).

**Invoked at:** Stage D4 (research paper draft), before D5/D6; any LaTeX portions in hybrid H4/H5/H6

```bash
cd plugins/folio && python scripts/check_artifacts.py workspace/
```

Reads `route.json` to determine mode. For LaTeX drafts, checks:
- All `\cite{key}` references exist in `refs.bib`
- All `\ref{}` targets exist in `captions.json` or figure plan
- Basic LaTeX structural validity (document class, `\begin{document}`, balanced environments)

**Exit codes:**
- `0` — No broken references or structural errors
- Non-zero — Missing citations, broken refs, or LaTeX structural errors (Gate F failure)

!!! tip "When to re-run"
    Re-run `check_artifacts.py` after every substantive edit to `drafts/paper.tex` and before Stages D5/D6 or hybrid H5/H6.

---

### `scan_redlines.py`

**Purpose:** IP/redline safety scanner — checks draft content against `ip_policy.json`.

**Invoked at:** Stage W5 (white paper review), D5 (research paper review), H5 (hybrid review)

```bash
cd plugins/folio && python scripts/scan_redlines.py workspace/
```

Reads `ip_policy.json` (if present) and scans all draft files for:
- Exact `forbidden_terms` matches
- `sensitive_metric_patterns` regex matches
- `code_names` appearances where they should not appear

Writes `reviews/ip_safety_report.md` with file paths, line numbers, and matched patterns.

**Exit codes:**
- `0` — No violations (or no `ip_policy.json` present)
- Non-zero — Violations found (IP Gate: blocks shipping until resolved or acknowledged)

See [IP Policy](ip-policy.md) for `ip_policy.json` configuration.

---

### `verify_citations.py`

**Purpose:** Validate citation pool and `refs.bib` integrity (Gate D: Citation integrity).

**Invoked at:** Stage D3-3B (literature verification)

```bash
cd plugins/folio && python scripts/verify_citations.py workspace/
```

Checks that:
- All citations in `citation_pool.json` have `verified: true` or are explicitly acknowledged as unverified
- No duplicate BibTeX keys in `refs.bib`
- All keys in `refs.bib` exist in `citation_pool.json`

**Exit codes:**
- `0` — Citation pool and BibTeX valid
- Non-zero — Unverified entries, duplicate keys, or pool/BibTeX mismatch

---

### `compile_package.sh`

**Purpose:** Compile LaTeX source into a PDF package using `pdflatex` and `bibtex`.

**Invoked at:** Stage D6 (research paper finalize), H6 (hybrid export)

```bash
cd plugins/folio && bash scripts/compile_package.sh workspace/
```

Runs from the Folio plugin root with the workspace path argument (i.e. `cd plugins/folio && ...`). Expects `final/paper.tex` and `final/refs.bib`.

- **Success:** Reports path to `final/paper.pdf`
- **Failure:** Retains `.tex`/`.bib`/figures; documents missing PDF in user report

This script requires `pdflatex` and `bibtex` on PATH. Folio degrades gracefully if they are absent — the source bundle is still delivered.

**Exit codes:**
- `0` — PDF compiled successfully
- Non-zero — Compilation error (source bundle still delivered; error is documented)

---

### `package_exports.py`

**Purpose:** Mode-aware export packager — assembles the final bundle under `final/` and `exports/`.

**Invoked at:** Shared Exit (all modes, after Human Checkpoint 3)

```bash
cd plugins/folio && python scripts/package_exports.py workspace/
```

Reads `route.json` to determine the effective mode (respects `user_override`) and assembles:
- **White paper:** `paper.md`, `executive_summary.md`, `bd_talking_points.md`, reviews, logs
- **Research paper:** `paper.tex`, `refs.bib`, figures, tables, `paper.pdf` if compiled
- **Hybrid:** Combined bundle with all applicable artifacts

Prints the output directory to stdout. Creates `submission_bundle.zip` if applicable.

**Exit codes:**
- `0` — Bundle assembled; output directory printed to stdout
- Non-zero — Packaging gate failure (treat same as any gate failure per Error Handling)

!!! warning "Non-zero exit"
    If `package_exports.py` returns non-zero, treat it as a packaging gate failure — same error handling as Gates B–G.
