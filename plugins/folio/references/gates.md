# Validation Gates Reference

## Contents

- [Gate A — Input Validation](#gate-a--input-validation)
- [Gate B — Plan Completeness](#gate-b--plan-completeness)
- [Gate C — Claim Ledger](#gate-c--claim-ledger)
- [Gate D — Citation Integrity](#gate-d--citation-integrity)
- [Gate E — Artifact Integrity](#gate-e--artifact-integrity)
- [Gate F — Structural Integrity](#gate-f--structural-integrity)
- [Gate G — Quality Non-Regression](#gate-g--quality-non-regression)
- [Gate H — Packaging](#gate-h--packaging)
- [IP Gate — Redline Scan](#ip-gate--redline-scan)
- [RC — Routing Checkpoint](#rc--routing-checkpoint)

---

## Gate A — Input Validation

| Field | Value |
|-------|-------|
| **Trigger** | End of Stage 1 (Prep and Normalization), before Checkpoint 1 |
| **Script** | `python scripts/validate_inputs.py workspace/` |
| **Pass** | Exit 0. Warnings acceptable; errors block. |
| **Fail** | Fix canonical inputs under `inputs/`; re-run validator. |

Also re-run after editing any `inputs/*` file or after `classify_materials` / `route_mode` if inputs change.

---

## Gate B — Plan Completeness

| Field | Value |
|-------|-------|
| **Trigger** | End of Stage D2 (research paper Global Planning) |
| **Script** | None (manual checklist) |
| **Pass** | All five planning artifacts exist (`outline.json`, `claim_ledger.json`, `figure_plan.json`, `literature_plan.json`, `results_inventory.json`). Outline covers standard venue sections. Every claim has `support_level`; every `unsupported` claim explicitly flagged. Figure plan covers outline-referenced figures. Literature plan covers citation needs. |
| **Fail** | Add missing artifacts or fill gaps; no silent unsupported claims. |

**Scope:** Research paper mode only. White paper skips Gate B. Hybrid uses Gate B only where D2-equivalent planning applies.

---

## Gate C — Claim Ledger

| Field | Value |
|-------|-------|
| **Trigger** | After claim ledger creation/update: W3 (white paper), D3-3A (research paper evidence accounting), H2/H3 (hybrid) |
| **Script** | `python scripts/build_claim_ledger.py workspace/` |
| **Pass** | Script exits 0. |
| **Fail** | Fix JSON and claims until pass. In research paper mode (D3-3A): block if any claim remains `unsupported` without user acknowledgment or if numerical claims lack traceable sources. |

---

## Gate D — Citation Integrity

| Field | Value |
|-------|-------|
| **Trigger** | End of D3-3B (Literature discovery) |
| **Script** | None (manual verification) |
| **Pass** | No unverified entries in `citation_pool.json`. No duplicate BibTeX keys in `refs.bib`. All citations verified via DOI or search. |
| **Fail** | Remove or verify flagged citations; deduplicate BibTeX keys. |

---

## Gate E — Artifact Integrity

| Field | Value |
|-------|-------|
| **Trigger** | End of D3-3C (Figure and table pipeline) |
| **Script** | None (manual verification) |
| **Pass** | Every outline-referenced figure/table exists or is explicitly deferred. All required captions present in `captions.json`. |
| **Fail** | Generate missing figures, flag for user provision, or record explicit deferral. |

---

## Gate F — Structural Integrity

| Field | Value |
|-------|-------|
| **Trigger** | End of D4 (Draft Composition), also before D5/D6 and H5/H6 for LaTeX bodies |
| **Script** | `python scripts/check_artifacts.py workspace/` |
| **Pass** | Script exits 0. All `\cite{}` keys exist in `refs.bib`; all `\ref{}` labels resolve. |
| **Fail** | Fix broken cites/refs per script output. Re-run after every substantive edit to `drafts/paper.tex`. |

---

## Gate G — Quality Non-Regression

| Field | Value |
|-------|-------|
| **Trigger** | After each review/repair round in W5, D5, H5 |
| **Script** | None (scorecard comparison) |
| **Pass** | `overall` score in `scorecard.json` does not drop vs. prior best round. |
| **Fail** | **Revert** to the better-scoring draft. Max 3 review rounds total; keep best-scoring artifact and document residual issues. |

---

## Gate H — Packaging

| Field | Value |
|-------|-------|
| **Trigger** | After `package_exports.py` runs (shared exit, all modes) |
| **Script** | `python scripts/package_exports.py workspace/` |
| **Pass** | Script exits 0. Output directory listing confirmed. |
| **Fail** | Treat as packaging gate failure per Error Handling protocol. |

---

## IP Gate — Redline Scan

| Field | Value |
|-------|-------|
| **Trigger** | During review stage of every mode (W5, D5, H5) — mandatory before declaring review complete |
| **Script** | `python scripts/scan_redlines.py workspace/` |
| **Pass** | No violations in `reviews/ip_safety_report.md`. |
| **Fail** | **BLOCK** shipping. List forbidden terms/patterns found. Suggest redactions per `ip_policy.json`. User must: redact, rewrite, or explicitly acknowledge risk (logged in `logs/run_log.md`). Do not mark stage complete until resolved. |

---

## RC — Routing Checkpoint

| Field | Value |
|-------|-------|
| **Trigger** | After Checkpoint 1 approval, before entering any mode-specific stage |
| **Script** | `python scripts/route_mode.py workspace/` (already run in Stage 1; read `route.json`) |
| **Pass** | User confirms recommended mode or provides explicit override. |
| **Fail** | Do not proceed into mode-specific stages. If user overrides, set `user_override` in `route.json` with reasons. Log decision in `logs/checkpoints.md`. |
