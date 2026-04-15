#!/usr/bin/env python3
"""Validate claim ledger integrity (Gate C: Evidence integrity)."""

import json
import sys
from pathlib import Path

RECOGNIZED_CLAIM_TYPES = frozenset(
    {
        "quantitative",
        "qualitative",
        "methodological",
        "fact",
        "interpretation",
        "opinion",
        "forecast",
    }
)


def validate_claim_ledger(workspace_path: str) -> bool:
    root = Path(workspace_path)
    ledger_path = root / "planning" / "claim_ledger.json"
    errors: list[str] = []
    warnings: list[str] = []

    if not ledger_path.exists():
        print("ERROR: claim_ledger.json not found", file=sys.stderr)
        return False

    try:
        data = json.loads(ledger_path.read_text())
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in claim_ledger.json: {e}", file=sys.stderr)
        return False

    claims = data.get("claims", [])
    if not claims:
        errors.append("Claim ledger is empty — no claims registered")

    for claim in claims:
        cid = claim.get("id", "unknown")
        statement = claim.get("statement", "")
        support = claim.get("support_level", "")
        evidence = claim.get("evidence_source", "")
        ctype = claim.get("type", "")

        if not statement:
            errors.append(f"{cid}: Empty claim statement")

        if ctype == "interpretation" and support in ("weak", "unsupported"):
            errors.append(f"{cid}: Interpretation claim requires at least moderate support")

        if support == "unsupported":
            if ctype != "interpretation":
                errors.append(f"{cid}: Claim is unsupported — must resolve or remove before drafting")
        elif support == "weak":
            if ctype not in ("opinion", "forecast", "interpretation"):
                warnings.append(f"{cid}: Weak support — consider softening language in draft")
        elif support not in ("strong", "moderate", "weak", "unsupported"):
            warnings.append(f"{cid}: Unrecognized support level '{support}'")

        if ctype and ctype not in RECOGNIZED_CLAIM_TYPES:
            warnings.append(f"{cid}: Unrecognized claim type '{ctype}'")

        if ctype in ("quantitative", "fact") and not evidence:
            label = "Quantitative" if ctype == "quantitative" else "Fact"
            errors.append(f"{cid}: {label} claim has no evidence_source trace")

    # Report
    if warnings:
        print("WARNINGS:")
        for w in warnings:
            print(f"  - {w}")

    if errors:
        print("ERRORS:")
        for e in errors:
            print(f"  - {e}")
        print(f"\nGate C FAILED: {len(errors)} evidence integrity error(s)")
        return False

    print(f"Gate C PASSED: {len(claims)} claim(s) validated")
    if warnings:
        print(f"  ({len(warnings)} warning(s))")
    return True


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: build_claim_ledger.py <workspace_path>", file=sys.stderr)
        sys.exit(1)
    ok = validate_claim_ledger(sys.argv[1])
    sys.exit(0 if ok else 1)
