#!/usr/bin/env python3
"""Render backlog as a framed Unicode dashboard with ANSI color.

Invoked by list-backlog.sh. Env:
  MODE    = open | archived | all
  COMPACT = "1" for tab-separated plain output
  ROOT    = path to .orc/backlog
  WIDTH   = terminal columns
"""
from __future__ import annotations
import json
import os
import sys
from datetime import date, datetime
from pathlib import Path

MODE = os.environ.get("MODE", "open")
COMPACT = os.environ.get("COMPACT") == "1"
ROOT = Path(os.environ.get("ROOT", ".orc/backlog"))
try:
    WIDTH = int(os.environ.get("WIDTH", "80"))
except ValueError:
    WIDTH = 80
WIDTH = max(60, min(WIDTH, 120))

USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR") and not COMPACT

C = {
    "reset": "\033[0m" if USE_COLOR else "",
    "dim":   "\033[2m" if USE_COLOR else "",
    "bold":  "\033[1m" if USE_COLOR else "",
    "red":   "\033[31m" if USE_COLOR else "",
    "yel":   "\033[33m" if USE_COLOR else "",
    "grn":   "\033[32m" if USE_COLOR else "",
    "cya":   "\033[36m" if USE_COLOR else "",
    "mag":   "\033[35m" if USE_COLOR else "",
}

ARCHIVED_STATUSES = {"archived", "dropped", "promoted", "done"}


def load_items() -> tuple[list[dict], list[dict]]:
    """Return (open_items, archived_items)."""
    idx = ROOT / "BACKLOG.jsonl"
    openi: list[dict] = []
    arch: list[dict] = []
    if idx.exists():
        for line in idx.read_text().splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("status") in ARCHIVED_STATUSES:
                arch.append(obj)
            else:
                openi.append(obj)
    # Also pull from archive/*.jsonl
    arch_dir = ROOT / "archive"
    if arch_dir.is_dir():
        for f in sorted(arch_dir.glob("*.jsonl")):
            for line in f.read_text().splitlines():
                line = line.strip()
                if line:
                    try:
                        arch.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
    return openi, arch


def age_of(created: str) -> str:
    if not created:
        return "?"
    try:
        d = datetime.strptime(created, "%Y-%m-%d").date()
    except ValueError:
        return "?"
    days = (date.today() - d).days
    if days <= 0:   return "today"
    if days == 1:   return "1d"
    if days < 7:    return f"{days}d"
    if days < 30:   return f"{days//7}w"
    if days < 365:  return f"{days//30}mo"
    return f"{days//365}y"


def prio_badge(p: str) -> tuple[str, int]:
    """Return (colored_text, visible_width)."""
    if p == "p1":
        return f"{C['bold']}{C['red']}p1{C['reset']}", 2
    if p == "p2":
        return f"{C['bold']}{C['yel']}p2{C['reset']}", 2
    if p == "p3":
        return f"{C['dim']}p3{C['reset']}", 2
    return f"{C['dim']}??{C['reset']}", 2


def trunc(s: str, n: int) -> str:
    if n <= 0:
        return ""
    return s if len(s) <= n else s[: n - 1] + "…"


def tags_str(tags) -> str:
    if isinstance(tags, list):
        return " ".join(str(t) for t in tags)
    if isinstance(tags, str):
        return tags
    return ""


def render_compact(items: list[dict]) -> None:
    for it in items:
        print(f"{it.get('id','')}\t{it.get('priority','')}\t{it.get('title','')}")


def section(title: str, items: list[dict]) -> None:
    inner = WIDTH - 2  # space between │ and │
    # Columns
    id_w = 4
    prio_w = 2
    age_w = 5
    tag_w = min(max(14, inner // 4), 22)
    gaps = 5  # gaps of 2 spaces between cols + leading space = adjusted below
    # Layout: " id  prio  title…  age  tags "
    #         leading 1 + id_w + 2 + prio_w + 2 + title_w + 2 + age_w + 2 + tag_w + trailing 1
    fixed = 1 + id_w + 2 + prio_w + 2 + 2 + age_w + 2 + tag_w + 1
    title_w = inner - fixed
    if title_w < 12:
        title_w = 12
        tag_w = max(6, inner - (1 + id_w + 2 + prio_w + 2 + title_w + 2 + age_w + 2 + 1))

    hdr_visible = f"{title} · {len(items)} item{'' if len(items)==1 else 's'}"
    hdr_colored = f"{C['bold']}{title}{C['reset']}{C['dim']} · {len(items)} item{'' if len(items)==1 else 's'}{C['reset']}"
    pad = inner - 3 - len(hdr_visible)  # 3 = "─ " + " "
    if pad < 0:
        pad = 0
    print(f"{C['dim']}╭─ {C['reset']}{hdr_colored}{C['dim']} {'─' * pad}╮{C['reset']}")

    if not items:
        msg = "  (empty — /orc add <idea> to capture)"
        print(f"{C['dim']}│{C['reset']}{C['dim']}{msg}{C['reset']}{' ' * (inner - len(msg))}{C['dim']}│{C['reset']}")
    else:
        for it in items:
            iid = str(it.get("id", "?"))[:id_w].ljust(id_w)
            badge, badge_w = prio_badge(it.get("priority", ""))
            ttl = trunc(it.get("title", ""), title_w).ljust(title_w)
            age = age_of(it.get("created", "")).ljust(age_w)[:age_w]
            tags = trunc(tags_str(it.get("tags", [])), tag_w).ljust(tag_w)

            # Build visible and colored versions
            colored = (
                f" {iid}  {badge}  {ttl}  "
                f"{C['yel']}{age}{C['reset']}  "
                f"{C['dim']}{tags}{C['reset']} "
            )
            visible_len = 1 + id_w + 2 + badge_w + 2 + title_w + 2 + age_w + 2 + tag_w + 1
            extra_pad = inner - visible_len
            if extra_pad < 0:
                extra_pad = 0
            print(f"{C['dim']}│{C['reset']}{colored}{' ' * extra_pad}{C['dim']}│{C['reset']}")

    print(f"{C['dim']}╰{'─' * inner}╯{C['reset']}")


def main() -> int:
    if not ROOT.exists():
        print(f"{C['dim']}No backlog initialized at {ROOT}{C['reset']}")
        print(f"{C['dim']}Run /orc add <idea> to start capturing.{C['reset']}")
        return 0

    openi, arch = load_items()

    if COMPACT:
        if MODE == "open":      render_compact(openi)
        elif MODE == "archived": render_compact(arch)
        else:                    render_compact(openi + arch)
        return 0

    if MODE == "open":
        section("Backlog — open", openi)
    elif MODE == "archived":
        section("Backlog — archived", arch)
    else:
        section("Backlog — open", openi)
        print()
        section("Backlog — archived", arch)

    # Footer hint
    if MODE != "archived" and openi:
        all_ids = [int(i.get("id", 0)) for i in openi + arch if str(i.get("id", "")).isdigit()]
        next_id = f"{(max(all_ids) if all_ids else 0) + 1:03d}"
        print(
            f"{C['dim']}  /orc pick <id>  →  promote to plan     "
            f"/orc drop <id>  →  archive     "
            f"next id: {next_id}{C['reset']}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
