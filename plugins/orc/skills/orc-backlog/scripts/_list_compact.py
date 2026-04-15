#!/usr/bin/env python3
"""Machine-readable backlog dump. TSV: id<TAB>priority<TAB>title."""
import json
import os
import sys
from pathlib import Path

root = Path(os.environ["ROOT"])
mode = os.environ["MODE"]
ARCHIVED = {"archived", "dropped", "promoted", "done"}

idx = root / "BACKLOG.jsonl"
if not idx.exists():
    sys.exit(0)

for line in idx.read_text().splitlines():
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        continue
    is_archived = obj.get("status") in ARCHIVED
    if mode == "open" and is_archived:
        continue
    if mode == "archived" and not is_archived:
        continue
    print(f"{obj.get('id','')}\t{obj.get('priority','')}\t{obj.get('title','')}")
