#!/usr/bin/env python3
"""Mode-aware export packager: route.json → workspace/final/ + submission_bundle.zip."""

import json
import shutil
import sys
import zipfile
from pathlib import Path


def _effective_mode(route: dict) -> str:
    override = route.get("user_override")
    if isinstance(override, str) and override:
        return override
    return str(route.get("selected_mode", ""))


def _gather_white_paper_tasks(root: Path) -> list[tuple[Path, Path]]:
    tasks: list[tuple[Path, Path]] = []
    final = root / "final"
    mapping = [
        (root / "drafts" / "paper.md", final / "drafts" / "paper.md"),
        (root / "reviews" / "ip_safety_report.md", final / "reviews" / "ip_safety_report.md"),
        (root / "reviews" / "hostile_review.md", final / "reviews" / "hostile_review.md"),
        (root / "planning" / "claim_ledger.json", final / "claims.json"),
        (root / "exports" / "executive_summary.md", final / "exports" / "executive_summary.md"),
        (root / "exports" / "bd_talking_points.md", final / "exports" / "bd_talking_points.md"),
    ]
    tasks.extend(mapping)
    return tasks


def _gather_research_paper_tasks(root: Path) -> list[tuple[Path, Path]]:
    tasks: list[tuple[Path, Path]] = []
    final = root / "final"
    tasks.append((root / "drafts" / "paper.tex", final / "drafts" / "paper.tex"))
    tasks.append((root / "citations" / "refs.bib", final / "citations" / "refs.bib"))
    tasks.append((root / "reviews" / "ip_safety_report.md", final / "reviews" / "ip_safety_report.md"))
    tasks.append((root / "reviews" / "scorecard.json", final / "reviews" / "scorecard.json"))

    for sub in ("figures", "tables"):
        src_dir = root / sub
        if src_dir.is_dir():
            for f in sorted(src_dir.rglob("*")):
                if f.is_file():
                    rel = f.relative_to(src_dir)
                    tasks.append((f, final / sub / rel))
    return tasks


def _dedupe_tasks(tasks: list[tuple[Path, Path]]) -> list[tuple[Path, Path]]:
    seen: set[Path] = set()
    out: list[tuple[Path, Path]] = []
    for src, dst in tasks:
        if dst in seen:
            continue
        seen.add(dst)
        out.append((src, dst))
    return out


def package_exports(workspace_path: str) -> bool:
    root = Path(workspace_path)
    route_path = root / "route.json"
    final_root = root / "final"

    if not route_path.exists():
        print(f"ERROR: route.json not found at {route_path}", file=sys.stderr)
        return False

    try:
        route = json.loads(route_path.read_text())
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in route.json: {e}", file=sys.stderr)
        return False

    mode = _effective_mode(route)
    if mode not in {"white_paper", "research_paper", "hybrid"}:
        print(f"ERROR: Unknown or missing mode: {mode!r}", file=sys.stderr)
        return False

    tasks: list[tuple[Path, Path]] = []
    if mode == "white_paper":
        tasks = _gather_white_paper_tasks(root)
    elif mode == "research_paper":
        tasks = _gather_research_paper_tasks(root)
    else:
        tasks = _dedupe_tasks(_gather_white_paper_tasks(root) + _gather_research_paper_tasks(root))

    if final_root.exists():
        shutil.rmtree(final_root)
    final_root.mkdir(parents=True, exist_ok=True)

    copied = 0
    for src, dst in tasks:
        if not src.exists():
            print(f"WARN: Missing source (skipped): {src.relative_to(root) if src.is_relative_to(root) else src}")
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        copied += 1

    files_to_zip = sorted(
        p for p in final_root.rglob("*") if p.is_file()
    )

    zip_path = final_root / "submission_bundle.zip"
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for path in files_to_zip:
            arc = path.relative_to(final_root).as_posix()
            zf.write(path, arcname=arc)

    print(f"OK: Packaged {copied} file(s) for {mode} mode")
    return True


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: package_exports.py <workspace_path>", file=sys.stderr)
        sys.exit(1)
    ok = package_exports(sys.argv[1])
    sys.exit(0 if ok else 1)
