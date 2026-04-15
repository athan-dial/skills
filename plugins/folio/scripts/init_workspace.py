#!/usr/bin/env python3
"""Initialize a Folio workspace with canonical directory structure."""

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

WORKSPACE_DIRS = [
    "inputs/raw_materials",
    "planning",
    "citations",
    "figures/generated",
    "figures/supplied",
    "tables/generated",
    "drafts/sections",
    "reviews",
    "final/figures",
    "final/tables",
    "logs",
    "exports",
]

SEED_FILES = {
    "inputs/idea.md": "# Idea\n\n<!-- Fill in or let the prep stage synthesize this -->\n",
    "inputs/experimental_log.md": "# Experimental Log\n\n<!-- Fill in or let the prep stage synthesize this -->\n",
    "inputs/venue_profile.md": "# Venue Profile\n\n<!-- Fill in or let the prep stage synthesize this -->\n",
    "inputs/materials_manifest.json": json.dumps({"files": [], "gaps": []}, indent=2) + "\n",
    "inputs/figures_manifest.json": json.dumps({"figures": [], "planned": []}, indent=2) + "\n",
    "inputs/materials_passport.json": json.dumps({"materials": []}, indent=2) + "\n",
    "intent.json": json.dumps(
        {
            "paper_id": "",
            "audience": "",
            "doc_type": "",
            "thesis": "",
            "constraints": "",
            "forbidden_topics": [],
            "preferred_mode": None,
            "output_bundle": "",
        },
        indent=2,
    )
    + "\n",
    "ip_policy.json": json.dumps(
        {
            "forbidden_terms": [],
            "code_names": [],
            "sensitive_metric_patterns": [],
            "redline_exceptions": [],
        },
        indent=2,
    )
    + "\n",
    "route.json": json.dumps(
        {
            "selected_mode": "",
            "confidence": 0.0,
            "reasons": [],
            "user_override": None,
        },
        indent=2,
    )
    + "\n",
    "logs/checkpoints.md": "# Checkpoints\n\n| Stage | Status | Timestamp |\n|-------|--------|-----------|\n",
}


def init_workspace(workspace_path: str) -> None:
    root = Path(workspace_path)

    if root.exists() and any(root.iterdir()):
        print(f"WARNING: Workspace already exists at {root}. Skipping creation of existing files.")

    for d in WORKSPACE_DIRS:
        (root / d).mkdir(parents=True, exist_ok=True)

    for filepath, content in SEED_FILES.items():
        target = root / filepath
        if not target.exists():
            target.write_text(content)

    # Initialize run log
    run_log = root / "logs" / "run_log.md"
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    if not run_log.exists():
        run_log.write_text(f"# Run Log\n\n## Session started: {ts}\n\n")
    else:
        with open(run_log, "a") as f:
            f.write(f"\n## Session resumed: {ts}\n\n")

    print(f"OK: Workspace initialized at {root}")
    print(f"  Directories: {len(WORKSPACE_DIRS)}")
    print(f"  Seed files: {len(SEED_FILES)}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: init_workspace.py <workspace_path>", file=sys.stderr)
        sys.exit(1)
    init_workspace(sys.argv[1])
