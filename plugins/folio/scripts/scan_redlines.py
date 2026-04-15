#!/usr/bin/env python3
"""IP/redline safety scanner: policy vs drafts → workspace/reviews/ip_safety_report.md."""

import json
import re
import sys
from pathlib import Path


def _line_number(text: str, pos: int) -> int:
    return text.count("\n", 0, pos) + 1


def _rel_workspace(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def _is_exception(matched_text: str, exceptions_lower: set[str]) -> bool:
    return matched_text.lower() in exceptions_lower


def scan_redlines(workspace_path: str) -> bool:
    root = Path(workspace_path)
    policy_path = root / "ip_policy.json"
    drafts_dir = root / "drafts"
    report_path = root / "reviews" / "ip_safety_report.md"

    violations: list[str] = []
    warnings: list[str] = []

    if not policy_path.exists():
        print(f"ERROR: ip_policy.json not found at {policy_path}", file=sys.stderr)
        return False

    try:
        policy = json.loads(policy_path.read_text())
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in ip_policy.json: {e}", file=sys.stderr)
        return False

    forbidden = policy.get("forbidden_terms") or []
    code_names = policy.get("code_names") or []
    metric_patterns = policy.get("sensitive_metric_patterns") or []
    exceptions = policy.get("redline_exceptions") or []
    exceptions_lower = {str(x).lower() for x in exceptions}

    compiled_metrics: list[tuple[str, re.Pattern[str]]] = []
    for i, pat in enumerate(metric_patterns):
        p = str(pat)
        try:
            compiled_metrics.append((p, re.compile(p)))
        except re.error as e:
            print(f"ERROR: Invalid sensitive_metric_patterns[{i}] ({p!r}): {e}", file=sys.stderr)
            return False

    if not drafts_dir.is_dir():
        report_path.parent.mkdir(parents=True, exist_ok=True)
        body = f"""# IP Safety Report
## Violations (0)
## Warnings (0)
## Status: PASS
"""
        report_path.write_text(body)
        print("WARN: workspace/drafts/ not found — no files scanned")
        print(f"Wrote {report_path}")
        return True

    draft_files = sorted(
        p
        for p in drafts_dir.rglob("*")
        if p.is_file() and p.suffix.lower() in {".md", ".tex", ".txt"}
    )

    for path in draft_files:
        rel = _rel_workspace(path, root)
        text = path.read_text(encoding="utf-8", errors="replace")

        for term in forbidden:
            t = str(term)
            if not t:
                continue
            tl = t.lower()
            search_start = 0
            while True:
                idx = text.lower().find(tl, search_start)
                if idx < 0:
                    break
                matched = text[idx : idx + len(t)]
                line = _line_number(text, idx)
                if _is_exception(matched, exceptions_lower):
                    warnings.append(
                        f'- [EXCEPTION] "{matched}" found but listed in exceptions in {rel} line {line}'
                    )
                else:
                    violations.append(f'- [FORBIDDEN] "{t}" found in {rel} line {line}')
                search_start = idx + max(1, len(tl))

        for term in code_names:
            t = str(term)
            if not t:
                continue
            try:
                cre = re.compile(r"\b" + re.escape(t) + r"\b", re.IGNORECASE)
            except re.error:
                continue
            for m in cre.finditer(text):
                matched = m.group(0)
                line = _line_number(text, m.start())
                if _is_exception(matched, exceptions_lower):
                    warnings.append(
                        f'- [EXCEPTION] "{matched}" found but listed in exceptions in {rel} line {line}'
                    )
                else:
                    violations.append(f'- [CODE_NAME] "{matched}" found in {rel} line {line}')

        for pat_str, cre in compiled_metrics:
            for m in cre.finditer(text):
                matched = m.group(0)
                line = _line_number(text, m.start())
                if _is_exception(matched, exceptions_lower):
                    warnings.append(
                        f'- [EXCEPTION] "{matched}" found but listed in exceptions in {rel} line {line}'
                    )
                else:
                    violations.append(
                        f'- [SENSITIVE_METRIC] pattern {pat_str!r} matched "{matched}" in {rel} line {line}'
                    )

    nv = len(violations)
    nw = len(warnings)
    status = "FAIL" if nv else "PASS"

    report_lines = [
        "# IP Safety Report",
        f"## Violations ({nv})",
    ]
    if violations:
        report_lines.extend(violations)
    report_lines.extend(
        [
            f"## Warnings ({nw})",
        ]
    )
    if warnings:
        report_lines.extend(warnings)
    report_lines.extend(["", f"## Status: {status}", ""])

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(report_lines))

    print(f"Wrote {report_path}")
    print(f"Violations: {nv}, Warnings: {nw}, Status: {status}")
    return nv == 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: scan_redlines.py <workspace_path>", file=sys.stderr)
        sys.exit(1)
    ok = scan_redlines(sys.argv[1])
    sys.exit(0 if ok else 1)
