# Schemas Reference

All JSON manifest schemas live under `templates/manifests/`. Folio validates artifacts against these schemas during gate checks — scripts enforce validation, so artifacts must conform before gates pass.

!!! tip "Don't paste schemas into chat"
    Folio's internal instruction is to validate against these schemas, not to reproduce them in full during a session. Use this reference to understand expected shapes when debugging gate failures.

---

## `intent.schema.json`

**Purpose:** Authoring intent and constraints for a paper workflow run.

**Written by:** `init_workspace.py` from user responses at Stage 0.

**Location:** `workspace/intent.json`

**Key fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `paper_id` | string | Yes | Unique identifier for the run |
| `audience` | string | Yes | Who must understand the output (e.g., executives, specialists, mixed) |
| `doc_type` | enum | Yes | `white_paper`, `research_paper`, or `hybrid` |
| `thesis` | string | Yes | Central claim or promise (one or two sentences) |
| `constraints` | string | No | Length, tone, confidentiality, deadlines, tooling |
| `forbidden_topics` | string[] | No | Topics or claims to avoid |
| `preferred_mode` | enum / null | No | User's preferred mode, or null for automatic routing |
| `output_bundle` | string | No | Output packaging preference |

---

## `route.schema.json`

**Purpose:** Selected document mode and routing rationale from `route_mode.py`.

**Written by:** `route_mode.py` at Stage 1.

**Location:** `workspace/route.json`

**Key fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `selected_mode` | enum | Yes | `white_paper`, `research_paper`, or `hybrid` |
| `confidence` | number (0–1) | Yes | Routing confidence score |
| `reasons` | string[] | Yes | Bullet explanations for the recommendation |
| `user_override` | enum / null | No | Explicit user override of selected mode |

!!! warning "Confidence below 0.5"
    Routing confidence below 0.5 means materials are ambiguous. Folio asks for explicit mode selection rather than proceeding automatically.

---

## `materials_manifest.schema.json`

**Purpose:** Inventory of raw materials provided for the workflow.

**Written by:** `prep_materials.py` at Stage 1.

**Location:** `workspace/inputs/materials_manifest.json`

**Key fields:**

| Field | Type | Description |
|-------|------|-------------|
| `files[].path` | string | Relative path from workspace root |
| `files[].type` | enum | `markdown`, `text`, `pdf`, `latex`, `bibtex`, `data`, `code`, `notebook`, `image`, `other` |
| `files[].extension` | string | File extension |
| `files[].size_bytes` | integer | File size |
| `files[].description` | string | Human-readable description |
| `files[].relevance` | enum | `high`, `medium`, `low`, `unknown` |
| `summary.total_files` | integer | Total file count |
| `summary.by_type` | object | Count per file type |
| `gaps` | string[] | Identified material gaps |

---

## `materials_passport.schema.json`

**Purpose:** Per-material provenance, classification, and allowed-use policy.

**Written by:** `classify_materials.py` at Stage 1.

**Location:** `workspace/inputs/materials_passport.json`

**Key fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `materials[].material_id` | string | Yes | Unique material identifier |
| `materials[].source_type` | enum | Yes | `internal_data`, `public_data`, `literature`, `proprietary_doc`, `code` |
| `materials[].classification` | enum | Yes | `public`, `internal`, `confidential` |
| `materials[].allowed_use` | enum | Yes | `cite`, `reference`, `embed`, `redact_and_reference` |
| `materials[].summary` | string | No | Human-readable description |
| `materials[].redaction_required` | boolean | No | Whether content must be redacted before use (default: false) |

---

## `claim_ledger.schema.json`

**Purpose:** Maps paper claims to evidence sources and support levels.

**Written by:** Folio during planning stages (W3, D2, H2); validated by `build_claim_ledger.py`.

**Location:** `workspace/planning/claim_ledger.json`

**Key fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `claims[].id` | string | Yes | Pattern `C\d+` (e.g., `C1`, `C12`) |
| `claims[].statement` | string | Yes | The claim text |
| `claims[].type` | enum | Yes | `quantitative`, `qualitative`, `methodological`, `fact`, `interpretation`, `opinion`, `forecast` |
| `claims[].evidence_source` | string | No | Reference to evidence (file path, result id, citation key) |
| `claims[].support_level` | enum | Yes | `strong`, `moderate`, `weak`, `unsupported` |
| `claims[].depends_on_figures` | string[] | No | Figure ids this claim requires |
| `claims[].depends_on_citations` | string[] | No | BibTeX keys this claim requires |
| `claims[].notes` | string | No | Free-text notes |

!!! tip "Claim types by mode"
    White paper and hybrid modes use `fact`, `interpretation`, `opinion`, `forecast`. Research paper mode uses `quantitative`, `qualitative`, `methodological`. All types are valid in all modes.

---

## `figures_manifest.schema.json`

**Purpose:** Inventory of figures and tables available or planned.

**Written by:** Folio during Stage 1 synthesis from raw materials.

**Location:** `workspace/inputs/figures_manifest.json`

**Key fields:**

| Field | Type | Description |
|-------|------|-------------|
| `figures[].path` | string | Relative path to figure file |
| `figures[].description` | string | Figure description |
| `figures[].type` | enum | `chart`, `diagram`, `table`, `photo`, `screenshot`, `other` |
| `figures[].format` | string | File format (e.g., `png`, `pdf`, `svg`) |
| `figures[].needs_regeneration` | boolean | Whether the figure needs to be remade |
| `planned[].description` | string | Description of a planned figure |
| `planned[].type` | string | Figure type |
| `planned[].data_source` | string | Where the data for this figure comes from |
| `planned[].priority` | enum | `required` or `nice-to-have` |

---

## `citation_pool.schema.json`

**Purpose:** Verified citation metadata for the manuscript.

**Written by:** Folio during Stage D3-3B literature discovery; validated by `verify_citations.py`.

**Location:** `workspace/citations/citation_pool.json`

**Key fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `citations[].key` | string | Yes | BibTeX citation key |
| `citations[].title` | string | Yes | Paper title |
| `citations[].authors` | string[] | No | Author list |
| `citations[].year` | integer | No | Publication year |
| `citations[].venue` | string | No | Journal or conference |
| `citations[].doi` | string | No | DOI |
| `citations[].url` | string | No | URL |
| `citations[].verified` | boolean | Yes | Whether the citation's existence was confirmed |
| `citations[].relevance_area` | string | No | Which coverage area this citation serves |
| `citations[].relevance_score` | number (0–1) | No | Relevance score |

!!! warning "Unverified citations"
    Only citations with `verified: true` enter `refs.bib`. Gate D blocks on unverified pool entries.

---

## `ip_policy.schema.json`

**Purpose:** Terms, patterns, and exceptions for IP-safe output.

**Read by:** `scan_redlines.py` during review stages.

**Location:** `workspace/ip_policy.json`

**Key fields:**

| Field | Type | Description |
|-------|------|-------------|
| `forbidden_terms` | string[] | Exact strings that must not appear in drafts or exports |
| `code_names` | string[] | Approved public stand-in names for internal projects |
| `sensitive_metric_patterns` | string[] | Regex patterns for quantitative claims needing human review |
| `redline_exceptions` | string[] | Terms allowed even when they resemble forbidden patterns |

See [IP Policy](ip-policy.md) for full configuration guidance.

---

## `scorecard.schema.json`

**Purpose:** Quality scores from a review round.

**Written by:** Folio during review stages (W5, D5, H5).

**Location:** `workspace/reviews/scorecard.json`

**Key fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `round` | integer | Yes | Review round number (1–3) |
| `scores.argument_coherence` | number (1–10) | Yes | Argument flow and logical consistency |
| `scores.evidence_support` | number (1–10) | Yes | Claim-to-evidence traceability |
| `scores.citation_quality` | number (1–10) | Yes | Citation accuracy and coverage |
| `scores.writing_clarity` | number (1–10) | Yes | Prose clarity and precision |
| `scores.venue_fit` | number (1–10) | Yes | Alignment with target venue requirements |
| `scores.overall` | number (1–10) | Yes | Aggregate score (Gate G watches this across rounds) |
| `blocking_issues` | string[] | No | Issues that must be resolved before export |
| `suggestions` | string[] | No | Non-blocking improvement suggestions |

!!! warning "Gate G"
    If `overall` drops between rounds, Folio automatically reverts to the higher-scoring draft. Scores must be comparable across rounds on the same scale.
