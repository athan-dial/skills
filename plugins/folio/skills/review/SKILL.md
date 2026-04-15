---
name: folio:review
description: "IP/redline scan, hostile review (white paper + hybrid), standard review with scorecard, and repair loop (max 3 rounds)."
trigger: /folio:review
---

# folio:review — Review and Repair

Run IP scanning, mode-appropriate review passes, scorecard generation, and repair loop.

## Entry Conditions

- Draft exists: `drafts/paper.md` (white paper/hybrid) and/or `drafts/paper.tex` (research paper/hybrid).
- Read `route.json` for effective mode.

If draft is missing, direct user to run `folio:draft` first.

## Protocol

### 1. IP Scan (All Modes)

```bash
python ../../scripts/scan_redlines.py workspace/
```

Writes **`reviews/ip_safety_report.md`**.

**IP Gate:** If violations found, **BLOCK** — do not proceed until cleared, redacted, or explicitly acknowledged by user. Log acknowledgments in `logs/run_log.md`. See `../../references/gates.md` for IP gate failure handling.

### 2. Hostile Review (White Paper + Hybrid Only)

Read `drafts/paper.md` as an external critic. Write **`reviews/hostile_review.md`**:
- Logical gaps
- Unsupported assertions
- Competitive risk
- Clarity issues
- Factual risk

For research paper mode, skip this step.

### 3. Standard Review (All Modes)

Write **`reviews/review_round_1.md`**:
- Argument flow, claim support, citations, figures/tables, clarity, venue fit, line-level suggestions.

Write **`reviews/scorecard.json`** with dimensions:
- `argument_coherence`
- `evidence_support`
- `citation_quality`
- `writing_clarity`
- `venue_fit`
- `overall` (numeric, consistent scale across rounds)
- `blocking_issues` (list of strings; empty when clear)
- `suggestions`

### 4. Repair Loop

If blocking issues exist:

1. Apply fixes to draft.
2. Save revised draft.
3. Re-score with new `reviews/scorecard.json`.

**Gate G — Quality non-regression:** If `overall` drops vs. prior best, **revert** to the better draft.

**Max 3 review rounds.** After 3 rounds, keep the best-scoring artifact and document residual issues.

### 5. Hybrid Mode: Dual Review

For hybrid, both tracks must pass:
- Conceptual parts: hostile review gate.
- Evidence parts: standard review + scorecard gate.
No "average failure" — fix or defer with user sign-off.

## Exit Conditions

- At least one review round completed.
- Best draft selected.
- Blocking issues resolved or explicitly deferred by user.
- IP scan clean or violations acknowledged.
- Gate G passes.

## Next Stage

Proceed to `folio:export`.
