#!/usr/bin/env python3
"""Infer document mode from intent and materials passport; write route.json."""

import json
import sys
from pathlib import Path

DATA_NOTEBOOK_TYPES = frozenset({"data", "code", "notebook"})

EXPERIMENTAL_HINTS = (
    "experiment",
    "empirical",
    "benchmark",
    "ablation",
    "evaluation",
    "statistical",
    "p-value",
    "hypothesis",
    "dataset",
    "results",
)


def _load_json(path: Path, label: str) -> tuple[dict | None, str | None]:
    if not path.exists():
        return None, f"Missing {label} at {path}"
    try:
        return json.loads(path.read_text()), None
    except json.JSONDecodeError as e:
        return None, f"Invalid JSON in {path}: {e}"


def _white_paper_signals(intent: dict, passport: dict, manifest_types: dict[str, str]) -> tuple[int, int]:
    """Returns (hits, total) for white_paper scoring."""
    doc_type = str(intent.get("doc_type") or "").lower()
    audience = str(intent.get("audience") or "").lower()
    mats = passport.get("materials")
    if not isinstance(mats, list):
        mats = []

    hits = 0
    total = 4

    if any(x in doc_type for x in ("white", "conceptual", "position")):
        hits += 1
    if any(x in audience for x in ("executive", "leadership", "bd")):
        hits += 1

    if mats:
        lit_or_public = sum(
            1
            for m in mats
            if isinstance(m, dict)
            and (m.get("classification") == "public" or m.get("source_type") == "literature")
        )
        if lit_or_public > len(mats) / 2:
            hits += 1
    # else: not "most" — 0 for this signal

    bad_internal = False
    for mid, mtype in manifest_types.items():
        pm = next((x for x in mats if isinstance(x, dict) and x.get("material_id") == mid), None)
        if pm and pm.get("source_type") == "internal_data" and mtype in DATA_NOTEBOOK_TYPES:
            bad_internal = True
            break
    if not bad_internal:
        hits += 1

    return hits, total


def _research_paper_signals(intent: dict, manifest_types: dict[str, str]) -> tuple[int, int]:
    doc_type = str(intent.get("doc_type") or "").lower()
    thesis = str(intent.get("thesis") or "").lower()
    constraints = str(intent.get("constraints") or "").lower()
    blob = f"{thesis} {constraints}"

    hits = 0
    total = 3

    has_research = "research" in doc_type or "manuscript" in doc_type
    has_paper = "paper" in doc_type and "white" not in doc_type
    if has_research or doc_type == "research_paper" or has_paper:
        hits += 1

    if any(t in DATA_NOTEBOOK_TYPES for t in manifest_types.values()):
        hits += 1

    if any(h in blob for h in EXPERIMENTAL_HINTS):
        hits += 1

    return hits, total


def _build_manifest_type_index(manifest: dict) -> dict[str, str]:
    out: dict[str, str] = {}
    files = manifest.get("files")
    if not isinstance(files, list):
        return out
    for entry in files:
        if isinstance(entry, dict) and isinstance(entry.get("path"), str):
            p = entry["path"].replace("\\", "/")
            mtype = entry.get("type")
            if isinstance(mtype, str):
                out[p] = mtype
    return out


def route_mode(workspace_path: str) -> int:
    root = Path(workspace_path)
    intent_path = root / "intent.json"
    passport_path = root / "inputs" / "materials_passport.json"
    manifest_path = root / "inputs" / "materials_manifest.json"
    out_path = root / "route.json"

    intent, err = _load_json(intent_path, "intent.json")
    if err:
        print(f"ERROR: {err}", file=sys.stderr)
        return 1
    passport, err = _load_json(passport_path, "materials passport")
    if err:
        print(f"ERROR: {err}", file=sys.stderr)
        return 1

    manifest: dict = {}
    if manifest_path.exists():
        try:
            manifest = json.loads(manifest_path.read_text())
        except json.JSONDecodeError as e:
            print(f"WARNING: Could not read materials manifest for routing extras: {e}", file=sys.stderr)

    manifest_types = _build_manifest_type_index(manifest)

    preferred = intent.get("preferred_mode")
    if preferred in ("white_paper", "research_paper", "hybrid"):
        payload = {
            "selected_mode": preferred,
            "confidence": 0.95,
            "reasons": ["user-specified preference"],
            "user_override": None,
        }
        out_path.write_text(json.dumps(payload, indent=2) + "\n")
        print(f"Recommended mode: {preferred} (confidence: 0.95)")
        for r in payload["reasons"]:
            print(f"  - {r}")
        print(f"Route written to {out_path}")
        return 0

    wp_hits, wp_total = _white_paper_signals(intent, passport, manifest_types)
    dp_hits, dp_total = _research_paper_signals(intent, manifest_types)

    wp_score = wp_hits / wp_total if wp_total else 0.0
    dp_score = dp_hits / dp_total if dp_total else 0.0

    has_wp = wp_hits > 0
    has_dp = dp_hits > 0
    if has_wp and has_dp:
        hy_score = (wp_score + dp_score) / 2.0
    else:
        hy_score = 0.0

    modes = [
        ("white_paper", wp_score),
        ("research_paper", dp_score),
        ("hybrid", hy_score),
    ]
    modes.sort(key=lambda x: x[1], reverse=True)

    top_score = modes[0][1]
    second_score = modes[1][1] if len(modes) > 1 else 0.0
    margin = top_score - second_score

    if top_score == 0.0 and second_score == 0.0:
        selected = "hybrid"
        confidence = 0.0
        reasons = ["insufficient routing signals; defaulting to hybrid"]
    elif margin <= 0.1:
        selected = "hybrid"
        confidence = round(margin, 2)
        reasons = [
            f"top two modes within 0.1 (margin={margin:.2f}); "
            f"scores white_paper={wp_score:.2f}, research_paper={dp_score:.2f}, hybrid={hy_score:.2f}"
        ]
    else:
        selected = modes[0][0]
        confidence = round(margin, 2)
        reasons = []
        if selected == "white_paper":
            reasons.append(f"white_paper signals {wp_hits}/{wp_total} (score {wp_score:.2f})")
            reasons.append(f"research_paper signals {dp_hits}/{dp_total} (score {dp_score:.2f})")
        elif selected == "research_paper":
            reasons.append(f"research_paper signals {dp_hits}/{dp_total} (score {dp_score:.2f})")
            reasons.append(f"white_paper signals {wp_hits}/{wp_total} (score {wp_score:.2f})")
        else:
            reasons.append(
                f"hybrid score {hy_score:.2f} (white_paper={wp_score:.2f}, research_paper={dp_score:.2f})"
            )

    payload = {
        "selected_mode": selected,
        "confidence": confidence,
        "reasons": reasons,
        "user_override": None,
    }
    out_path.write_text(json.dumps(payload, indent=2) + "\n")

    print(f"Recommended mode: {selected} (confidence: {payload['confidence']:.2f})")
    for r in reasons:
        print(f"  - {r}")
    print(f"Route written to {out_path}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: route_mode.py <workspace_path>", file=sys.stderr)
        sys.exit(1)
    sys.exit(route_mode(sys.argv[1]))
