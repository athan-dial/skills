---
name: folio:plan
description: "Mode-specific planning: perspective discovery and argument structure (white paper), global planning with 5 artifacts (research paper), or conceptual framing (hybrid)."
trigger: /folio:plan
---

# folio:plan — Mode-Specific Planning

Generate planning artifacts based on the confirmed mode. Read `route.json` to determine the effective mode (`user_override` takes precedence over `selected_mode`).

## Entry Conditions

- `route.json` exists with a confirmed mode.
- Canonical inputs available under `inputs/`.
- Human Checkpoint 1 and routing checkpoint approved (check `logs/checkpoints.md`).

If missing, direct user to run `folio:prep` first.

## Protocol by Mode

Reference `../../references/modes/*.md` for detailed mode protocols where available.

---

### White Paper (W2 + W3)

#### W2: Perspective Discovery

1. Scan `inputs/raw_materials/`, `idea.md`, and available external literature.
2. Write **`planning/perspectives.json`**: array of `{perspective_id, viewpoint, key_arguments, source_materials, relevance}`. At least 3 distinct perspectives (or user waiver).
3. Write **`planning/question_tree.json`**: structured questions grouped by planned section.

#### W3: Argument Structure

1. Formulate thesis and strongest counterthesis in **`planning/argument_graph.md`**.
2. Map claims to perspectives; plan ledger support for narrative sections.
3. Write **`planning/argument_graph.md`** — argument flow: sections, claims, dependencies.
4. Write **`planning/claim_ledger.json`** with extended types: `fact`, `interpretation`, `opinion`, `forecast`. Conform to `../../templates/manifests/claim_ledger.schema.json`.

**Gate C — Claim ledger:**

```bash
python ../../scripts/build_claim_ledger.py workspace/
```

Block on failure; fix until pass.

**Exit:** `perspectives.json`, `question_tree.json`, `argument_graph.md`, `claim_ledger.json` exist. Gate C passes.

---

### Research Paper (D2)

#### D2: Global Planning

1. Read canonical inputs thoroughly.
2. Generate **`planning/outline.json`** — title, sections array (`id`, `name`, `purpose`, `key_points`, `estimated_length`, `depends_on_figures`, `depends_on_citations`), `narrative_arc`.
3. Generate **`planning/claim_ledger.json`** — claims with `id`, `statement`, `type`, `evidence_source`, `support_level`, `depends_on_figures`, `depends_on_citations`, `notes`.
4. Generate **`planning/figure_plan.json`** — per figure: `id`, `description`, `type`, `source`, `source_path`, `supports_claims`, `caption_draft`.
5. Generate **`planning/literature_plan.json`** — `search_queries`, `known_references`, `coverage_areas` with min ref counts.
6. Generate **`planning/results_inventory.json`** — `results` entries: `id`, `description`, `value`, `source_file`, `supports_claims`, `verified`.

**Gate B — Plan completeness:**
- Outline includes standard venue sections.
- Every claim has `support_level`; `unsupported` claims explicitly flagged.
- Figure plan covers outline-referenced figures.
- Literature plan covers citation needs.

**Human Checkpoint 2:** Present outline, narrative arc, claim ledger summary (highlight weak/unsupported), figure and literature plans. Wait for explicit approval.

**Exit:** All 5 planning artifacts exist. Gate B passes. Checkpoint 2 approved.

---

### Hybrid (H2)

Follow W2 + W3 for the conceptual front-half:

- `planning/perspectives.json`
- `planning/question_tree.json`
- `planning/argument_graph.md`
- `planning/claim_ledger.json` (extended types)

**Gate C:**

```bash
python ../../scripts/build_claim_ledger.py workspace/
```

**Exit:** Same as white paper planning artifacts. Gate C passes.

## Next Stage

- White paper: proceed to `folio:draft` (white paper skips `folio:support`).
- Research paper: proceed to `folio:support`.
- Hybrid: proceed to `folio:support`.
