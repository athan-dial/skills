#!/usr/bin/env python3
"""Scan raw materials and produce an inventory for the prep stage."""

import json
import sys
from pathlib import Path

# Map file extensions to material types
EXT_TYPE_MAP = {
    ".md": "markdown",
    ".txt": "text",
    ".pdf": "pdf",
    ".tex": "latex",
    ".bib": "bibtex",
    ".csv": "data",
    ".tsv": "data",
    ".xlsx": "data",
    ".json": "data",
    ".py": "code",
    ".r": "code",
    ".R": "code",
    ".ipynb": "notebook",
    ".png": "image",
    ".jpg": "image",
    ".jpeg": "image",
    ".svg": "image",
    ".gif": "image",
    ".tiff": "image",
    ".eps": "image",
}


def scan_materials(workspace_path: str) -> None:
    root = Path(workspace_path)
    raw_dir = root / "inputs" / "raw_materials"

    if not raw_dir.exists():
        print("WARNING: No raw_materials directory found")
        print(json.dumps({"files": [], "gaps": ["No raw materials provided"]}, indent=2))
        return

    files = []
    type_counts: dict[str, int] = {}

    for f in sorted(raw_dir.rglob("*")):
        if f.is_dir():
            continue
        rel = str(f.relative_to(root))
        ext = f.suffix.lower()
        ftype = EXT_TYPE_MAP.get(ext, "other")
        size = f.stat().st_size

        type_counts[ftype] = type_counts.get(ftype, 0) + 1

        files.append({
            "path": rel,
            "type": ftype,
            "extension": ext,
            "size_bytes": size,
            "description": "",
            "relevance": "unknown",
        })

    manifest = {
        "files": files,
        "summary": {
            "total_files": len(files),
            "by_type": type_counts,
        },
        "gaps": [],
    }

    # Write manifest
    manifest_path = root / "inputs" / "materials_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")

    print(f"OK: Scanned {len(files)} file(s) in raw_materials/")
    for ftype, count in sorted(type_counts.items()):
        print(f"  {ftype}: {count}")
    print(f"Manifest written to {manifest_path}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: prep_materials.py <workspace_path>", file=sys.stderr)
        sys.exit(1)
    scan_materials(sys.argv[1])
