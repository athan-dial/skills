#!/usr/bin/env python3
"""orc status — single-pane view of all orc system state.

Design matches orc-backlog TUI language:
  - No frame. Whitespace + color hierarchy.
  - State dot (●/○/·) as leftmost scannable signal.
  - Content bright, metadata dim grey.
  - Graceful empty states — nothing running looks calm, not broken.
"""
from __future__ import annotations
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(os.environ.get("ROOT", "."))
try:
    WIDTH = int(os.environ.get("WIDTH", "80"))
except ValueError:
    WIDTH = 80
WIDTH = max(60, min(WIDTH, 120))

USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")

def _c(code: str) -> str:
    return code if USE_COLOR else ""

RESET = _c("\033[0m")
DIM = _c("\033[2m")
BOLD = _c("\033[1m")
GRN = _c("\033[38;5;108m")      # active — soft green
AMB = _c("\033[38;5;214m")      # warning / progress
RED = _c("\033[38;5;203m")      # failed
BLU = _c("\033[38;5;110m")      # identifiers — subdued blue
TITLE = _c("\033[38;5;253m")    # primary content — near-white
META = _c("\033[38;5;244m")     # metadata — mid-grey
FAINT = _c("\033[38;5;240m")    # captions, idle dots — dark grey


# ── data probes ───────────────────────────────────────────────────────────────
def read_plan_state() -> dict | None:
    """Read .orc/state.json if an orchestration is active."""
    p = ROOT / ".orc" / "state.json"
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text())
    except (json.JSONDecodeError, OSError):
        return None


def read_autoresearch() -> list[dict]:
    """Find running autoresearch loops via var/autoresearch/*/session.json."""
    results = []
    root = ROOT / "var" / "autoresearch"
    if not root.is_dir():
        return results
    for sess in root.glob("*/session.json"):
        try:
            obj = json.loads(sess.read_text())
            obj["_slug"] = sess.parent.name
            results.append(obj)
        except (json.JSONDecodeError, OSError):
            continue
    return results


def read_backlog_summary() -> dict:
    """Count open items by priority from .orc/backlog/BACKLOG.jsonl."""
    out = {"total": 0, "p1": 0, "p2": 0, "p3": 0, "other": 0}
    idx = ROOT / ".orc" / "backlog" / "BACKLOG.jsonl"
    if not idx.exists():
        return out
    archived = {"archived", "dropped", "promoted", "done"}
    try:
        for line in idx.read_text().splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("status") in archived:
                continue
            out["total"] += 1
            p = obj.get("priority", "")
            if p in ("p1", "p2", "p3"):
                out[p] += 1
            else:
                out["other"] += 1
    except OSError:
        pass
    return out


def read_last_commit() -> tuple[str, str, str] | None:
    """Return (short_hash, message, relative_time) or None."""
    if not (ROOT / ".git").exists():
        return None
    try:
        res = subprocess.run(
            ["git", "-C", str(ROOT), "log", "-1", "--format=%h%x1f%s%x1f%cr"],
            capture_output=True, text=True, check=True, timeout=3,
        )
        parts = res.stdout.strip().split("\x1f")
        if len(parts) == 3:
            return tuple(parts)  # type: ignore
    except (subprocess.SubprocessError, FileNotFoundError):
        pass
    return None


# ── render helpers ────────────────────────────────────────────────────────────
def trunc(s: str, n: int) -> str:
    if n <= 0 or len(s) <= n:
        return s
    return s[: max(1, n - 1)] + "…"


def row(dot: str, label: str, content: str, meta: str = "") -> None:
    """Render one status row with aligned columns.
    Layout:  "  <dot> <label:13>  <content>  <meta (right-aligned)>"
    """
    label_w = 13
    # Visible budget for content + meta
    inner = WIDTH - 2 - 1 - 1 - label_w - 2 - 2  # indent, dot, gap, label, gap, trailing
    meta_w = len(meta)
    content_room = inner - meta_w - 2 if meta else inner
    if content_room < 10:
        content_room = max(10, inner - 2)
        meta = ""  # drop meta if squeezed
        meta_w = 0

    content_truncated = trunc(content, content_room)
    content_padded = content_truncated.ljust(content_room)

    if meta:
        line = (
            f"  {dot} {META}{label.ljust(label_w)}{RESET}  "
            f"{TITLE}{content_padded}{RESET}  "
            f"{DIM}{meta}{RESET}"
        )
    else:
        line = (
            f"  {dot} {META}{label.ljust(label_w)}{RESET}  "
            f"{TITLE}{content_padded}{RESET}"
        )
    print(line)


def active_dot() -> str:
    return f"{GRN}●{RESET}"

def idle_dot() -> str:
    return f"{FAINT}○{RESET}"

def passive_dot() -> str:
    return f"{FAINT}·{RESET}"

def failed_dot() -> str:
    return f"{BOLD}{RED}●{RESET}"


# ── sections ──────────────────────────────────────────────────────────────────
def render_plan(state: dict | None) -> bool:
    """Return True if plan is active."""
    if not state or not state.get("plan_ref"):
        row(idle_dot(), "plan", f"{FAINT}idle{RESET}", f"{FAINT}—{RESET}")
        return False

    slug = str(state.get("plan_ref", "")).rsplit("/", 1)[-1].replace(".md", "")
    wave = state.get("wave", "?")
    total_waves = state.get("total_waves", "?")
    inflight = state.get("inflight_jobs", "") or ""
    n_jobs = 0
    if isinstance(inflight, str):
        n_jobs = len([l for l in inflight.split("\n") if l.strip()])
    elif isinstance(inflight, list):
        n_jobs = len(inflight)
    status = state.get("wave_status", "")
    is_failed = str(status).lower() == "failed"
    dot = failed_dot() if is_failed else active_dot()

    meta = f"wave {wave}/{total_waves}"
    if n_jobs:
        meta += f" · {n_jobs} running"
    row(dot, "plan", slug, meta)
    return True


def render_autoresearch(sessions: list[dict]) -> bool:
    """Return True if any loop is active."""
    running = [s for s in sessions if str(s.get("status", "")).lower() in ("running", "active")]
    if not running:
        row(idle_dot(), "autoresearch", f"{FAINT}idle{RESET}", f"{FAINT}—{RESET}")
        return False
    # Render each active loop on its own row
    for s in running:
        slug = s.get("_slug", "?")
        it = s.get("iteration", "?")
        max_it = s.get("max_iterations", "?")
        metric = s.get("current_metric", None)
        baseline = s.get("baseline_metric", None)
        parts = [f"iter {it}/{max_it}"]
        if metric is not None:
            try:
                m = float(metric)
                parts.append(f"{m:.1%}" if m <= 1 else f"{m:.1f}")
                if baseline is not None:
                    b = float(baseline)
                    delta = (m - b) * (100 if m <= 1 else 1)
                    sign = "+" if delta >= 0 else ""
                    parts.append(f"({sign}{delta:.1f}pp)")
            except (TypeError, ValueError):
                pass
        meta = " · ".join(parts)
        row(active_dot(), "autoresearch", slug, meta)
    return True


def render_backlog(summary: dict) -> None:
    total = summary["total"]
    if total == 0:
        row(passive_dot(), "backlog", f"{FAINT}empty{RESET}", f"{FAINT}—{RESET}")
        return
    parts = []
    if summary["p1"]: parts.append(f"{RED}{summary['p1']} p1{RESET}")
    if summary["p2"]: parts.append(f"{AMB}{summary['p2']} p2{RESET}")
    if summary["p3"]: parts.append(f"{FAINT}{summary['p3']} p3{RESET}")
    # These already contain color codes — emit directly
    meta_raw = f"{FAINT} · {RESET}".join(parts) if parts else ""
    # Compose content
    content = f"{total} open"
    # Direct print since meta has its own ANSI
    label_w = 13
    content_room = WIDTH - 2 - 1 - 1 - label_w - 2 - 22  # approx reservation for meta
    content_padded = trunc(content, max(10, content_room)).ljust(max(10, content_room))
    print(
        f"  {passive_dot()} {META}{'backlog'.ljust(label_w)}{RESET}  "
        f"{TITLE}{content_padded}{RESET}  {meta_raw}"
    )


def render_commit(commit: tuple[str, str, str] | None) -> None:
    if not commit:
        row(passive_dot(), "last commit", f"{FAINT}(no git history){RESET}")
        return
    sha, msg, when = commit
    row(passive_dot(), "last commit", msg, f"{BLU}{sha}{RESET}{DIM} · {when}")


def render_hint(anything_active: bool, backlog_total: int) -> None:
    print()
    if anything_active:
        print(f"  {FAINT}/orc:handoff  checkpoint state     /orc:recap  full briefing{RESET}")
    elif backlog_total:
        print(f"  {FAINT}/orc:pick <id>  promote from backlog     /orc:scope  shape new work{RESET}")
    else:
        print(f"  {FAINT}/orc:scope  shape new work     /orc:add <idea>  capture for later{RESET}")


# ── main ──────────────────────────────────────────────────────────────────────
def main() -> int:
    state = read_plan_state()
    ar = read_autoresearch()
    backlog = read_backlog_summary()
    commit = read_last_commit()

    print()
    print(f"  {BOLD}orc{RESET}{FAINT}  ·  {ROOT.name}{RESET}")
    print()

    plan_active = render_plan(state)
    ar_active = render_autoresearch(ar)
    render_backlog(backlog)
    render_commit(commit)

    render_hint(plan_active or ar_active, backlog["total"])
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
