# IP policy template (`ip_policy.json`)

Use this shape when authoring `ip_policy.json` for a workspace. Values are examples only; replace with policies appropriate to your organization and publication context.

```json
{
  "forbidden_terms": ["Project Chimera", "internal-metric-xyz"],
  "code_names": ["Chimera", "Phoenix"],
  "sensitive_metric_patterns": ["\\d+\\.\\d+% improvement over internal"],
  "redline_exceptions": ["Folio"]
}
```

## Fields

- **forbidden_terms** — Exact strings that must not appear in drafts or exports. `scan_redlines.py` flags these for redaction or revision.

- **code_names** — Approved public or stand-in names for internal projects or programs. Use when the narrative must refer to a concept without using forbidden internal names.

- **sensitive_metric_patterns** — Regular-expression patterns matching quantitative claims that need human review or wording changes (for example, internal benchmarks or non-public comparators).

- **redline_exceptions** — Terms or phrases that are allowed even when they resemble forbidden patterns (product names, framework names, or other intentional public strings).
