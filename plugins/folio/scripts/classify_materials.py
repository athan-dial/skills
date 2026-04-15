#!/usr/bin/env python3
"""Classify materials from the manifest and write a materials passport."""

import json
import sys
from collections import Counter
from pathlib import Path

# Substrings in path/filename that suggest a citation-style source (pdf/md/text → literature).
LITERATURE_PATH_HINTS = (
    "paper",
    "reference",
    "references",
    "citation",
    "citations",
    "arxiv",
    "doi",
    "manuscript",
    "preprint",
    "journal",
    "article",
    "bibliography",
    "literature",
    "pubmed",
    "proceedings",
    "supplementary",
    "supplement",
)


def _path_suggests_literature(rel_path: str) -> bool:
    p = rel_path.lower().replace("\\", "/")
    return any(h in p for h in LITERATURE_PATH_HINTS)


def _infer_source_type(mtype: str, rel_path: str) -> str:
    if mtype in ("bibtex", "latex"):
        return "literature"
    if mtype == "image":
        return "internal_data"
    if mtype in ("data", "code", "notebook"):
        return "internal_data"
    if mtype in ("pdf", "markdown", "text"):
        if _path_suggests_literature(rel_path):
            return "literature"
        return "internal_data"
    # other / unknown
    return "internal_data"


def _classification_for_source(source_type: str) -> str:
    if source_type == "literature":
        return "public"
    return "internal"


def _allowed_use(source_type: str, mtype: str) -> str:
    if source_type == "literature":
        return "cite"
    if source_type == "internal_data" and mtype in ("data", "code", "notebook", "image"):
        return "embed"
    if source_type == "internal_data":
        return "reference"
    return "reference"


def classify_materials(workspace_path: str) -> int:
    root = Path(workspace_path)
    manifest_path = root / "inputs" / "materials_manifest.json"
    out_path = root / "inputs" / "materials_passport.json"

    if not manifest_path.exists():
        print(f"ERROR: Missing manifest at {manifest_path}", file=sys.stderr)
        return 1

    try:
        manifest = json.loads(manifest_path.read_text())
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in {manifest_path}: {e}", file=sys.stderr)
        return 1

    files = manifest.get("files")
    if not isinstance(files, list):
        print("ERROR: materials_manifest.json must contain a 'files' array", file=sys.stderr)
        return 1

    materials: list[dict] = []
    class_counts: Counter[str] = Counter()

    for entry in files:
        if not isinstance(entry, dict):
            print("ERROR: Each manifest file entry must be an object", file=sys.stderr)
            return 1
        rel = entry.get("path")
        mtype = entry.get("type")
        if not isinstance(rel, str) or not rel:
            print("ERROR: Each file entry must have a non-empty 'path' string", file=sys.stderr)
            return 1
        if not isinstance(mtype, str):
            print(f"ERROR: Invalid 'type' for path {rel!r}", file=sys.stderr)
            return 1

        material_id = rel.replace("\\", "/")
        source_type = _infer_source_type(mtype, rel)
        classification = _classification_for_source(source_type)
        allowed_use = _allowed_use(source_type, mtype)
        redaction_required = classification == "confidential"

        class_counts[classification] += 1

        materials.append(
            {
                "material_id": material_id,
                "source_type": source_type,
                "classification": classification,
                "allowed_use": allowed_use,
                "summary": "",
                "redaction_required": redaction_required,
            }
        )

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps({"materials": materials}, indent=2) + "\n")

    n = len(materials)
    print(f"OK: Classified {n} material(s)")
    for cls in sorted(class_counts.keys()):
        print(f"  {cls}: {class_counts[cls]}")
    print(f"Passport written to {out_path}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: classify_materials.py <workspace_path>", file=sys.stderr)
        sys.exit(1)
    sys.exit(classify_materials(sys.argv[1]))
