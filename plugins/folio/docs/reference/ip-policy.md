# IP Policy and Redline Scanning

Folio includes a mandatory IP safety layer that runs before any mode declares its review stage complete. This page explains how redline scanning works, how to configure `ip_policy.json`, and how to handle violations.

---

## How it works

Before marking review complete in any mode, Folio runs:

```bash
cd plugins/folio && python scripts/scan_redlines.py workspace/
```

This script reads `workspace/ip_policy.json` (if present) and scans all draft files for:

- **Forbidden terms** — Exact string matches that must not appear in any draft or export
- **Sensitive metric patterns** — Regex patterns matching quantitative claims that need human review
- **Code names** — Internal project names that may not have been replaced with approved public names

Scan results are written to `reviews/ip_safety_report.md` with file paths, line numbers, and matched content.

**The IP Gate is non-negotiable.** Folio will not mark a review stage complete with unaddressed violations. You must either:

1. Redact or rewrite the flagged content
2. Add the term to `redline_exceptions` if it is intentionally public
3. Explicitly acknowledge the risk (must be logged in `logs/run_log.md`)

If `ip_policy.json` does not exist, `scan_redlines.py` exits 0 (no violations). The scan still runs.

---

## Configuring `ip_policy.json`

Create `workspace/ip_policy.json` before drafting begins. The schema is defined in `templates/manifests/ip_policy.schema.json`.

**Example:**

```json
{
  "forbidden_terms": ["Project Chimera", "internal-metric-xyz"],
  "code_names": ["Chimera", "Phoenix"],
  "sensitive_metric_patterns": ["\\d+\\.\\d+% improvement over internal"],
  "redline_exceptions": ["Folio"]
}
```

---

## Fields

### `forbidden_terms`

Exact strings that must not appear in drafts or exports. `scan_redlines.py` flags every occurrence for redaction or revision.

Use this for:
- Internal project names that must not appear in published material
- Confidential identifiers or codenames
- Legally restricted terms

```json
"forbidden_terms": ["Project Chimera", "internal-metric-xyz", "Q3-roadmap-alpha"]
```

---

### `code_names`

Approved public or stand-in names for internal projects or programs. Use when the narrative must refer to a concept without using its forbidden internal name.

This field informs the scan context — `scan_redlines.py` uses it to detect where an internal name may have leaked instead of its approved substitute.

```json
"code_names": ["Chimera", "Phoenix"]
```

---

### `sensitive_metric_patterns`

Regular-expression patterns matching quantitative claims that need human review before publication. Use this for internal benchmarks, non-public comparators, or metric formats that reveal confidential performance data.

```json
"sensitive_metric_patterns": [
  "\\d+\\.\\d+% improvement over internal",
  "\\d+x faster than [A-Z][a-z]+ v\\d"
]
```

When a pattern matches, `scan_redlines.py` flags the line for review. Resolution options:
- Restate the metric in absolute terms without the internal comparator
- Remove the metric entirely
- Get explicit sign-off and log the acknowledgment

---

### `redline_exceptions`

Terms or phrases that are allowed even when they resemble forbidden patterns — for example, product names, framework names, or other intentional public strings that happen to match a `forbidden_terms` pattern.

```json
"redline_exceptions": ["Folio", "OpenAI"]
```

---

## Handling violations

When `scan_redlines.py` exits non-zero, Folio:

1. Lists all forbidden terms or patterns found (from `reviews/ip_safety_report.md`)
2. Suggests redactions or rephrasing per `ip_policy.json`
3. Asks you to choose: **redact**, **rewrite**, or **acknowledge risk**

If you choose to acknowledge risk, the decision must be explicit and logged in `logs/run_log.md`. Folio will not silently proceed past IP Gate failures.

---

## IP policy and the workflow

| Stage | Mode | When scan runs |
|-------|------|----------------|
| W5 | White paper | Before hostile review is complete |
| D5 | Research paper | Before review round 1 begins |
| H5 | Hybrid | Before either review track is complete |

The scan runs on all draft files — `drafts/paper.md`, `drafts/paper.tex`, and section intermediates. Export files are also scanned as part of final packaging.

---

## Security notes

- `ip_policy.json` should be created per-workspace, not committed to shared repositories unless terms are organization-wide defaults
- `scan_redlines.py` uses Python's `re` module for pattern matching — test regex patterns before adding them to `sensitive_metric_patterns`
- The `redline_exceptions` list bypasses checks selectively; keep it narrow

See [Failure Modes — Gate IP](failure-modes.md#gate-ip-redline-safety) for troubleshooting violation reports.
