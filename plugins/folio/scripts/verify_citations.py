#!/usr/bin/env python3
"""Validate citation pool and refs.bib integrity (Gate D: Citation integrity)."""

import json
import re
import sys
from pathlib import Path


def parse_bibtex_keys(bib_content: str) -> set[str]:
    """Extract citation keys from a BibTeX file."""
    return set(re.findall(r"@\w+\{(\w+),", bib_content))


def validate_citations(workspace_path: str) -> bool:
    root = Path(workspace_path)
    pool_path = root / "citations" / "citation_pool.json"
    bib_path = root / "citations" / "refs.bib"
    errors: list[str] = []
    warnings: list[str] = []

    # Check citation pool exists
    if not pool_path.exists():
        print("ERROR: citation_pool.json not found", file=sys.stderr)
        return False

    try:
        pool_data = json.loads(pool_path.read_text())
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in citation_pool.json: {e}", file=sys.stderr)
        return False

    citations = pool_data.get("citations", [])
    if not citations:
        warnings.append("Citation pool is empty")

    # Check for unverified citations
    pool_keys: set[str] = set()
    for cit in citations:
        key = cit.get("key", "unknown")
        if key in pool_keys:
            errors.append(f"Duplicate citation key: {key}")
        pool_keys.add(key)

        if not cit.get("verified", False):
            errors.append(f"Unverified citation: {key} — must verify before use in manuscript")

        if not cit.get("title"):
            warnings.append(f"{key}: Missing title")
        if not cit.get("authors"):
            warnings.append(f"{key}: Missing authors")

    # Check refs.bib exists and matches pool
    if not bib_path.exists():
        if citations:
            errors.append("refs.bib not found but citation pool is non-empty")
    else:
        bib_content = bib_path.read_text()
        bib_keys = parse_bibtex_keys(bib_content)

        # Keys in pool but not in bib
        missing_from_bib = pool_keys - bib_keys
        for k in missing_from_bib:
            errors.append(f"Citation {k} in pool but missing from refs.bib")

        # Keys in bib but not in pool (orphaned)
        orphaned = bib_keys - pool_keys
        for k in orphaned:
            warnings.append(f"BibTeX key {k} in refs.bib but not in citation pool (orphaned)")

    # Report
    if warnings:
        print("WARNINGS:")
        for w in warnings:
            print(f"  - {w}")

    if errors:
        print("ERRORS:")
        for e in errors:
            print(f"  - {e}")
        print(f"\nGate D FAILED: {len(errors)} citation integrity error(s)")
        return False

    print(f"Gate D PASSED: {len(citations)} citation(s) validated")
    if warnings:
        print(f"  ({len(warnings)} warning(s))")
    return True


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: verify_citations.py <workspace_path>", file=sys.stderr)
        sys.exit(1)
    ok = validate_citations(sys.argv[1])
    sys.exit(0 if ok else 1)
