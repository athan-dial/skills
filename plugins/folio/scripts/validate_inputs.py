#!/usr/bin/env python3
"""Validate canonical inputs in a Folio workspace (Gate A)."""

import json
import sys
from pathlib import Path

REQUIRED_FILES = {
    "inputs/idea.md": "Core idea document",
    "inputs/experimental_log.md": "Experimental log",
    "inputs/venue_profile.md": "Venue profile",
    "inputs/materials_manifest.json": "Materials manifest",
    "inputs/figures_manifest.json": "Figures manifest",
}

MIN_CONTENT_LENGTH = 50  # characters — a placeholder file is ~40 chars


def validate_inputs(workspace_path: str) -> bool:
    root = Path(workspace_path)
    errors: list[str] = []
    warnings: list[str] = []

    if not root.exists():
        print(f"ERROR: Workspace not found at {root}", file=sys.stderr)
        return False

    route_path = root / "route.json"
    selected_mode = None
    if route_path.exists():
        try:
            route_data = json.loads(route_path.read_text())
            selected_mode = route_data.get("selected_mode")
        except json.JSONDecodeError:
            selected_mode = None

    if route_path.exists():
        for rel_path, description in (
            ("intent.json", "Intent manifest"),
            ("inputs/materials_passport.json", "Materials passport"),
        ):
            if not (root / rel_path).exists():
                errors.append(f"MISSING: {rel_path} ({description})")

    # Check required files exist
    for rel_path, description in REQUIRED_FILES.items():
        target = root / rel_path
        if not target.exists():
            if rel_path == "inputs/experimental_log.md" and selected_mode == "white_paper":
                warnings.append(f"MISSING: {rel_path} ({description}) — optional in white_paper mode")
            else:
                errors.append(f"MISSING: {rel_path} ({description})")
            continue

        content = target.read_text().strip()

        # Check for placeholder content
        if "<!-- Fill in" in content and len(content) < MIN_CONTENT_LENGTH + 50:
            warnings.append(f"PLACEHOLDER: {rel_path} appears to be unsynthesized")
        elif len(content) < MIN_CONTENT_LENGTH:
            warnings.append(f"SPARSE: {rel_path} has very little content ({len(content)} chars)")

        # Check for GAP markers
        gap_count = content.count("<!-- GAP:")
        if gap_count > 0:
            warnings.append(f"GAPS: {rel_path} has {gap_count} unresolved gap(s)")

    # Validate JSON files parse correctly
    json_files = ["inputs/materials_manifest.json", "inputs/figures_manifest.json"]
    if route_path.exists():
        json_files.extend(["intent.json", "inputs/materials_passport.json"])
    for json_file in json_files:
        target = root / json_file
        if target.exists():
            try:
                json.loads(target.read_text())
            except json.JSONDecodeError as e:
                errors.append(f"INVALID JSON: {json_file}: {e}")

    # Report
    if warnings:
        print("WARNINGS:")
        for w in warnings:
            print(f"  - {w}")

    if errors:
        print("ERRORS:")
        for e in errors:
            print(f"  - {e}")
        print(f"\nGate A FAILED: {len(errors)} error(s)")
        return False

    print(f"Gate A PASSED: All {len(REQUIRED_FILES)} canonical inputs present")
    if warnings:
        print(f"  ({len(warnings)} warning(s) — review recommended)")
    return True


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: validate_inputs.py <workspace_path>", file=sys.stderr)
        sys.exit(1)
    ok = validate_inputs(sys.argv[1])
    sys.exit(0 if ok else 1)
