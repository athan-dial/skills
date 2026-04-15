# Command Reference

Folio exposes nine commands: one full-pipeline entry point and eight stage-specific sub-commands. Every sub-command can run standalone on an existing workspace.

---

## `/folio`

**Run the full pipeline or resume from a checkpoint.**

```
/folio [idea] [materials_path]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `idea` | No | One-line research idea (prompted if omitted) |
| `materials_path` | No | Path to raw materials folder (prompted if omitted) |

- If no workspace exists, runs the full pipeline from Stage 0.
- If a workspace path is provided and `logs/checkpoints.md` exists, offers to resume from the last completed stage.

---

## `/folio:init`

**Initialize a workspace and collect intent.**

```
/folio:init [idea] [materials_path]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `idea` | No | Research idea |
| `materials_path` | No | Path to raw materials |

**Entry condition:** No existing workspace required.

**Produces:** `workspace/` directory with canonical layout, `intent.json`, raw materials copied into `inputs/raw_materials/`.

**Scripts run:** `init_workspace.py`

---

## `/folio:prep`

**Normalize, classify, and route materials.**

```
/folio:prep [workspace_path]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace_path` | Yes | Path to an initialized workspace |

**Entry condition:** Stage 0 (init) complete. `intent.json` must exist.

**Produces:** Classified inputs (`idea.md`, `experimental_log.md`, `venue_profile.md`, manifests), `route.json` with mode recommendation.

**Scripts run:** `classify_materials.py`, `route_mode.py`, `validate_inputs.py`

**Gates:** Gate A (input completeness) -- `validate_inputs.py` must exit 0.

**Checkpoints:** Human Checkpoint 1 (prep approval) and routing checkpoint (mode confirmation).

---

## `/folio:plan`

**Mode-specific planning.**

```
/folio:plan [workspace_path]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace_path` | Yes | Path to a prepped workspace |

**Entry condition:** Stage 1 (prep) complete. Mode confirmed in `route.json`.

**Produces:** `outline.json`, `claim_ledger.json`, `figure_plan.json`, `literature_plan.json`. White paper and hybrid modes also produce `perspectives.json`, `question_tree.json`, `argument_graph.md`.

**Gates:** Gate B (plan coherence) -- outline must cover all claims in the ledger.

**Checkpoints:** Human Checkpoint 2 (planning approval before drafting).

---

## `/folio:support`

**Build evidence, literature, and figures.**

```
/folio:support [workspace_path]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace_path` | Yes | Path to a planned workspace |

**Entry condition:** Stage 2 (plan) complete.

**Produces:** `citations/citation_pool.json`, `citations/refs.bib`, generated figures in `figures/generated/`, `figures/captions.json`, `tables/generated/`.

**Gates:** Gate C (support completeness) -- every claim in the ledger must have at least one supporting artifact or an explicit gap marker.

---

## `/folio:draft`

**Compose the manuscript.**

```
/folio:draft [workspace_path]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace_path` | Yes | Path to a supported workspace |

**Entry condition:** Stage 3 (support) complete.

**Produces:** `drafts/paper.tex` (research paper / hybrid) or `drafts/paper.md` (white paper / hybrid), section files in `drafts/sections/`.

**Gates:** Gate D (draft completeness) -- all outline sections present, no unresolved `<!-- GAP -->` markers in required sections.

---

## `/folio:review`

**IP scan, critical review, and repair.**

```
/folio:review [workspace_path]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace_path` | Yes | Path to a drafted workspace |

**Entry condition:** Stage 4 (draft) complete.

**Produces:** `reviews/review_round_N.md`, `reviews/scorecard.json`, `reviews/ip_safety_report.md`. Regressions are repaired automatically; the draft is updated in place.

**Scripts run:** `scan_redlines.py`

**Gates:** IP Gate -- `scan_redlines.py` must exit 0 (no unacknowledged violations). Review Gate -- scorecard `overall` must not regress between rounds.

**Checkpoints:** Human Checkpoint 3 (final approval before export).

---

## `/folio:export`

**Finalize and package the manuscript.**

```
/folio:export [workspace_path]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace_path` | Yes | Path to a reviewed workspace |

**Entry condition:** Stage 5 (review) complete. Checkpoint 3 approved.

**Produces:** `final/` bundle (paper source, `refs.bib`, figures, optional compiled PDF). White paper and hybrid modes also produce `exports/executive_summary.md` and `exports/bd_talking_points.md`.

**Scripts run:** `package_exports.py`, `compile_package.sh` (if LaTeX toolchain available)

---

## `/folio:status`

**Show pipeline state for a workspace.**

```
/folio:status [workspace_path]
```

| Argument | Required | Description |
|----------|----------|-------------|
| `workspace_path` | Yes | Path to any workspace |

**Entry condition:** Workspace directory must exist.

**Produces:** No artifacts. Prints a table of completed stages, pending checkpoints, active mode, and any blocking gate failures. Reads from `logs/checkpoints.md` and `logs/run_log.md`.

---

## Resume behavior

When invoked on a workspace that already has progress:

1. `/folio` reads `logs/checkpoints.md` and offers to resume from the next incomplete stage.
2. Any stage command (e.g., `/folio:draft`) checks that its entry conditions are met. If prior stages are incomplete, it reports what is missing rather than silently failing.
3. Re-running a completed stage overwrites its artifacts. The previous versions are logged in `logs/run_log.md`.

---

## Examples

```
# Full pipeline from scratch
/folio "Benchmarking LLM routing strategies" ~/research/llm-routing/

# Initialize only, then come back later
/folio:init "Benchmarking LLM routing strategies" ~/research/llm-routing/

# Check where a workspace stands
/folio:status workspace/

# Jump straight to review on a drafted workspace
/folio:review workspace/

# Re-export after manual edits to the draft
/folio:export workspace/
```
