#!/usr/bin/env python3
"""Validate draft artifact references (Gates E + F: Artifact and rendering integrity)."""

import json
import re
import sys
from pathlib import Path


def validate_artifacts(workspace_path: str) -> bool:
    root = Path(workspace_path)
    errors: list[str] = []
    warnings: list[str] = []

    mode = "research_paper"
    route_path = root / "route.json"
    if route_path.exists():
        try:
            route_data = json.loads(route_path.read_text())
            mode = route_data.get("selected_mode", "research_paper")
        except (json.JSONDecodeError, OSError):
            mode = "research_paper"

    if not (root / "reviews" / "ip_safety_report.md").exists():
        warnings.append(
            "reviews/ip_safety_report.md not found (may not exist yet during drafting)"
        )

    bib_path = root / "citations" / "refs.bib"
    captions_path = root / "figures" / "captions.json"

    if mode == "white_paper":
        draft_path = root / "drafts" / "paper.md"
        if not draft_path.exists():
            print("ERROR: drafts/paper.md not found", file=sys.stderr)
            return False

        if captions_path.exists():
            try:
                captions_data = json.loads(captions_path.read_text())
                for cap in captions_data.get("captions", []):
                    fig_path = cap.get("path", "")
                    if fig_path and not (root / fig_path).exists():
                        if cap.get("exists", True):
                            errors.append(f"Figure file missing: {fig_path}")
            except json.JSONDecodeError:
                errors.append("captions.json is invalid JSON")

        if warnings:
            print("WARNINGS:")
            for w in warnings:
                print(f"  - {w}")

        if errors:
            print("ERRORS:")
            for e in errors:
                print(f"  - {e}")
            print(f"\nGates E/F FAILED: {len(errors)} artifact/rendering error(s)")
            return False

        print("Gates E/F PASSED: White paper draft and figure artifacts validated")
        if warnings:
            print(f"  ({len(warnings)} warning(s))")
        return True

    if mode == "hybrid":
        md_path = root / "drafts" / "paper.md"
        tex_exists = (root / "drafts" / "paper.tex").exists()
        if tex_exists and md_path.exists():
            if not md_path.read_text().strip():
                errors.append("drafts/paper.md is empty (hybrid mode)")
        elif tex_exists and not md_path.exists():
            warnings.append("drafts/paper.md not found (hybrid mode)")

    tex_path = root / "drafts" / "paper.tex"
    if not tex_path.exists():
        print("ERROR: drafts/paper.tex not found", file=sys.stderr)
        return False

    draft = tex_path.read_text()

    # --- Gate E: Artifact integrity ---

    # Check figure/table references resolve
    if captions_path.exists():
        try:
            captions_data = json.loads(captions_path.read_text())
            known_figures = set()
            for cap in captions_data.get("captions", []):
                known_figures.add(cap.get("figure_id", ""))
                # Check the actual file exists
                fig_path = cap.get("path", "")
                if fig_path and not (root / fig_path).exists():
                    if cap.get("exists", True):
                        errors.append(f"Figure file missing: {fig_path}")

            # Check \ref{fig:X} in draft against known figures
            fig_refs = set(re.findall(r"\\ref\{fig:(\w+)\}", draft))
            for ref in fig_refs:
                if ref not in known_figures:
                    errors.append(
                        f"\\ref{{fig:{ref}}} in draft but no matching figure in captions.json"
                    )

        except json.JSONDecodeError:
            errors.append("captions.json is invalid JSON")
    else:
        # Check if draft references any figures at all
        if re.search(r"\\ref\{fig:", draft):
            warnings.append("Draft references figures but captions.json not found")

    # --- Gate D (draft-level): Citation references ---
    cite_keys_in_draft = set(re.findall(r"\\cite[tp]?\{([^}]+)\}", draft))
    # Expand comma-separated keys
    all_cite_keys: set[str] = set()
    for group in cite_keys_in_draft:
        for key in group.split(","):
            all_cite_keys.add(key.strip())

    if bib_path.exists():
        bib_content = bib_path.read_text()
        bib_keys = set(re.findall(r"@\w+\{(\w+),", bib_content))
        for key in all_cite_keys:
            if key not in bib_keys:
                errors.append(f"\\cite{{{key}}} in draft but not in refs.bib")
    elif all_cite_keys:
        errors.append(f"Draft cites {len(all_cite_keys)} key(s) but refs.bib not found")

    # --- Gate F: Rendering integrity (structural checks) ---

    # Check basic LaTeX structure
    if "\\begin{document}" not in draft:
        errors.append("Missing \\begin{document}")
    if "\\end{document}" not in draft:
        errors.append("Missing \\end{document}")

    # Check balanced environments
    begins = re.findall(r"\\begin\{(\w+)\}", draft)
    ends = re.findall(r"\\end\{(\w+)\}", draft)
    begin_counts: dict[str, int] = {}
    end_counts: dict[str, int] = {}
    for b in begins:
        begin_counts[b] = begin_counts.get(b, 0) + 1
    for e in ends:
        end_counts[e] = end_counts.get(e, 0) + 1
    for env in set(list(begin_counts.keys()) + list(end_counts.keys())):
        bc = begin_counts.get(env, 0)
        ec = end_counts.get(env, 0)
        if bc != ec:
            errors.append(f"Unbalanced environment: {env} (begin={bc}, end={ec})")

    # Check template exists if referenced
    if "\\documentclass" not in draft:
        warnings.append("No \\documentclass found — may be using an external template")

    # Report
    if warnings:
        print("WARNINGS:")
        for w in warnings:
            print(f"  - {w}")

    if errors:
        print("ERRORS:")
        for e in errors:
            print(f"  - {e}")
        print(f"\nGates E/F FAILED: {len(errors)} artifact/rendering error(s)")
        return False

    print("Gates E/F PASSED: All artifact references and LaTeX structure validated")
    if warnings:
        print(f"  ({len(warnings)} warning(s))")
    return True


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: check_artifacts.py <workspace_path>", file=sys.stderr)
        sys.exit(1)
    ok = validate_artifacts(sys.argv[1])
    sys.exit(0 if ok else 1)
