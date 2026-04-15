#!/usr/bin/env python3
"""Render backlog as a clean, minimal TUI.

Design philosophy:
  - No frame. A box only pays off for very long lists; otherwise it's visual noise.
  - Information hierarchy through color, not weight. Title is the only bright text;
    everything else (id, priority label, tags, age) is dim so the eye lands on content.
  - Priority as a colored dot (●/○) on the leftmost column — scannable in peripheral vision.
  - Priority grouping only when the list is long enough to benefit from it (>6 items).
  - Tags as dim `·`-separated chips, right-sized to the actual content.
  - Age dim and right-aligned.
  - Dynamic title truncation — only clips when the terminal actually can't fit it.
  - Helpful, calm empty states instead of apologetic "(empty)".

Invoked by list-backlog.sh. Env:
  MODE    = open | archived | all
  COMPACT = "1" for tab-separated plain output
  ROOT    = path to .orc/backlog
  WIDTH   = terminal columns
"""
from __future__ import annotations
import json
import os
import shutil
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

# ── palette ───────────────────────────────────────────────────────────────────
def _c(code: str) -> str:
    return code if USE_COLOR else ""

RESET = _c("\033[0m")
DIM = _c("\033[2m")
BOLD = _c("\033[1m")
RED = _c("\033[38;5;203m")       # p1 — soft red, not fire-engine
YEL = _c("\033[38;5;214m")       # p2 — warm amber
BLU = _c("\033[38;5;110m")       # IDs — subdued blue
TITLE = _c("\033[38;5;253m")     # titles — near-white
META = _c("\033[38;5;244m")      # metadata (tags, age) — mid-grey
FAINT = _c("\033[38;5;240m")     # separators, captions — dark grey

ARCHIVED_STATUSES = {"archived", "dropped", "promoted", "done"}
GROUP_THRESHOLD = 6  # group-by-priority headers only if more items than this

# ── data ──────────────────────────────────────────────────────────────────────
def load_items() -> tuple[list[dict], list[dict]]:
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
            (arch if obj.get("status") in ARCHIVED_STATUSES else openi).append(obj)
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
        return ""
    try:
        d = datetime.strptime(created, "%Y-%m-%d").date()
    except ValueError:
        return ""
    days = (date.today() - d).days
    if days <= 0:   return "today"
    if days == 1:   return "1d"
    if days < 7:    return f"{days}d"
    if days < 30:   return f"{days//7}w"
    if days < 365:  return f"{days//30}mo"
    return f"{days//365}y"


def prio_dot(p: str) -> str:
    """Single-glyph priority indicator. One char wide."""
    if p == "p1":
        return f"{BOLD}{RED}●{RESET}"
    if p == "p2":
        return f"{YEL}●{RESET}"
    if p == "p3":
        return f"{FAINT}○{RESET}"
    return f"{FAINT}·{RESET}"


def tags_as_chips(tags) -> tuple[str, int]:
    """Return (colored_chip_string, visible_width)."""
    if isinstance(tags, list):
        parts = [str(t) for t in tags if t]
    elif isinstance(tags, str):
        parts = tags.split()
    else:
        return "", 0
    if not parts:
        return "", 0
    sep = f" {FAINT}·{RESET} "
    sep_visible = 3  # " · "
    visible = sum(len(p) for p in parts) + sep_visible * (len(parts) - 1)
    colored = sep.join(f"{META}{p}{RESET}" for p in parts)
    return colored, visible


# ── layout ────────────────────────────────────────────────────────────────────
def sort_by_priority(items: list[dict]) -> list[dict]:
    order = {"p1": 0, "p2": 1, "p3": 2}
    return sorted(
        items,
        key=lambda it: (order.get(it.get("priority", ""), 3), str(it.get("id", ""))),
    )


def priority_label(p: str) -> str:
    return {"p1": "HIGH", "p2": "MEDIUM", "p3": "LOW"}.get(p, "OTHER")


def render_item(it: dict) -> None:
    """Render one item row. Visual budget: 2 + 1 + 2 + 4 + 2 + title + 2 + tags + 2 + age."""
    dot = prio_dot(it.get("priority", ""))
    iid = str(it.get("id", "?")).rjust(3)[:3]
    title = str(it.get("title", "")).strip()
    age = age_of(it.get("created", ""))
    chips, chips_w = tags_as_chips(it.get("tags", []))

    # Fixed-width pieces (visible widths)
    # "  ● " = 4, "001 " = 4, title, "  " gap, tags, "  " gap, age, trailing " "
    left_w = 2 + 1 + 1 + 3 + 1  # indent + dot + space + id + space
    right_w = len(age) + 1      # age + trailing space

    # Tags + gap take up: 2 + chips_w (if any)
    tags_budget = (2 + chips_w) if chips_w else 0

    # Remaining room for title
    title_room = WIDTH - left_w - tags_budget - right_w - 2  # - 2 for gap before age
    if title_room < 10:
        # Squeeze tags first
        chips, chips_w = "", 0
        tags_budget = 0
        title_room = WIDTH - left_w - right_w - 2

    if len(title) > title_room:
        title = title[: max(1, title_room - 1)] + "…"

    title_padded = title.ljust(title_room)

    if chips_w:
        # Fill any extra space between title and chips; then 2 spaces, chips, 2 spaces, age
        chip_pad = title_room - len(title)  # already padded, so 0; we want chips right after
        line = (
            f"  {dot} {BLU}{iid}{RESET}  "
            f"{TITLE}{title}{RESET}"
            f"{' ' * chip_pad}  "
            f"{chips}  "
            f"{DIM}{YEL}{age}{RESET}"
        )
    else:
        line = (
            f"  {dot} {BLU}{iid}{RESET}  "
            f"{TITLE}{title_padded}{RESET}  "
            f"{DIM}{YEL}{age}{RESET}"
        )
    print(line)


def render_group_header(label: str, first: bool = False) -> None:
    if not first:
        print()
    print(f"  {FAINT}{label}{RESET}")


def render_section_header(text: str, subtle: bool = False) -> None:
    if subtle:
        print(f"{FAINT}{text}{RESET}")
    else:
        print(f"{BOLD}{text}{RESET}")


def render_rule() -> None:
    # Thin dim rule, 24 chars
    print(f"  {FAINT}{'─' * 24}{RESET}")


def render_compact(items: list[dict]) -> None:
    for it in items:
        print(f"{it.get('id','')}\t{it.get('priority','')}\t{it.get('title','')}")


def render_open_section(items: list[dict], show_groups: bool) -> None:
    sorted_items = sort_by_priority(items)
    if show_groups and len(items) > GROUP_THRESHOLD:
        last_prio = None
        first = True
        for it in sorted_items:
            p = it.get("priority", "")
            if p != last_prio:
                render_group_header(priority_label(p), first=first)
                last_prio = p
                first = False
            render_item(it)
    else:
        for it in sorted_items:
            render_item(it)


def render_archived_section(items: list[dict]) -> None:
    if not items:
        return
    print()
    render_section_header("Archived", subtle=True)
    for it in sort_by_priority(items):
        render_item(it)


def render_empty_state() -> None:
    print()
    print(f"  {BOLD}Backlog{RESET}{DIM} is empty{RESET}")
    print()
    print(f"  {FAINT}Capture an idea with{RESET}  {META}/orc add <short description>{RESET}")
    print()


def render_footer(next_id: str) -> None:
    print()
    print(
        f"  {META}/orc pick{RESET}{FAINT} <id>  promote to plan    "
        f"{META}/orc drop{RESET}{FAINT} <id>  archive    "
        f"next id {META}{next_id}{RESET}"
    )


# ── main ──────────────────────────────────────────────────────────────────────
def main() -> int:
    if not ROOT.exists():
        print()
        print(f"  {META}No backlog at {ROOT}{RESET}")
        print(f"  {FAINT}/orc add <idea> to start capturing.{RESET}")
        print()
        return 0

    openi, arch = load_items()

    if COMPACT:
        if MODE == "open":       render_compact(openi)
        elif MODE == "archived": render_compact(arch)
        else:                    render_compact(openi + arch)
        return 0

    # Empty check first — skip header for empty states
    is_empty = (
        (MODE == "open" and not openi)
        or (MODE == "archived" and not arch)
        or (MODE == "all" and not openi and not arch)
    )
    if is_empty:
        render_empty_state()
        return 0

    # Header
    print()
    if MODE == "archived":
        hdr = f"Backlog {FAINT}·{RESET}{BOLD} {len(arch)} archived"
    elif MODE == "all":
        hdr = f"Backlog {FAINT}·{RESET}{BOLD} {len(openi)} open {FAINT}·{RESET}{BOLD} {len(arch)} archived"
    else:
        hdr = f"Backlog {FAINT}·{RESET}{BOLD} {len(openi)} open"
    print(f"  {BOLD}{hdr}{RESET}")
    print()

    # Body
    if MODE == "archived":
        for it in sort_by_priority(arch):
            render_item(it)
    elif MODE == "all":
        if openi:
            render_open_section(openi, show_groups=True)
        render_archived_section(arch)
    else:  # open
        render_open_section(openi, show_groups=True)

    # Footer (only when there are actionable items)
    if MODE != "archived" and openi:
        all_ids = [
            int(i.get("id", 0))
            for i in openi + arch
            if str(i.get("id", "")).isdigit()
        ]
        next_id = f"{(max(all_ids) if all_ids else 0) + 1:03d}"
        render_footer(next_id)
    else:
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
