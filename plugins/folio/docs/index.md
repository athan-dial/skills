# Folio

**Folio** is a Claude Code skill pack for end-to-end research manuscript orchestration. It converts a research idea and a folder of materials into a validated, reviewable, exportable manuscript — through a structured pipeline of artifact-driven stages, deterministic quality gates, and human approval checkpoints.

---

## What Folio does

Folio runs inside Claude Code and manages the full lifecycle of a research paper:

- **Normalizes** loose notes, PDFs, experiment logs, and figures into canonical input artifacts
- **Plans** an outline, claim ledger, figure plan, and literature map
- **Drafts** an integrated manuscript (Markdown or LaTeX, depending on mode)
- **Reviews** the draft critically, runs IP safety scanning, and reverts regressions automatically
- **Exports** a clean final bundle with bibliography, figures, and an optional compiled PDF

Three human checkpoints pause the workflow at critical junctions — after prep, after planning, and before final export.

---

## Modes

Folio branches into three modes after prep, based on what your materials look like:

| Mode | Best for | Draft format |
|------|----------|--------------|
| [White paper](guides/modes/white-paper.md) | Conceptual framing, executive narrative, strategic positioning | Markdown |
| [Research paper](guides/modes/research-paper.md) | Evidence-heavy research, empirical results, traditional venue submission | LaTeX |
| [Hybrid](guides/modes/hybrid.md) | Combined framing and evidence, merged narrative + data sections | Markdown + LaTeX |

Mode is recommended automatically by `route_mode.py` from your materials and intent. You confirm or override at the routing checkpoint.

---

## Commands

Folio can run as a full pipeline or stage-by-stage:

| Command | Purpose |
|---------|---------|
| `/folio` | Run full pipeline or resume from checkpoint |
| `/folio:init` | Initialize workspace and collect intent |
| `/folio:prep` | Normalize, classify, route materials |
| `/folio:plan` | Mode-specific planning |
| `/folio:support` | Evidence, literature, figures |
| `/folio:draft` | Compose manuscript |
| `/folio:review` | IP scan, review, repair |
| `/folio:export` | Finalize and package |
| `/folio:status` | Show pipeline state |

See [Command Reference](reference/commands.md) for full details.

---

## Guides

- [Getting Started](guides/getting-started.md) — Install, first invocation, what to expect
- [Workflow Overview](guides/workflow-overview.md) — Stage-by-stage walkthrough (Stages 0–6)
- [White Paper Mode](guides/modes/white-paper.md)
- [Research Paper Mode](guides/modes/research-paper.md)
- [Hybrid Mode](guides/modes/hybrid.md)

---

## Reference

- [Scripts](reference/scripts.md) — All helper scripts: purpose, usage, exit codes
- [Schemas](reference/schemas.md) — JSON manifest schemas and their key fields
- [Artifacts](reference/artifacts.md) — Complete artifact list organized by stage
- [IP Policy](reference/ip-policy.md) — Redline scanning and `ip_policy.json` configuration
- [Failure Modes](reference/failure-modes.md) — Gate failures, common problems, and repairs

---

## Quick start

```bash
# Install
git clone https://github.com/athan-dial/folio.git
ln -s "$(pwd)/folio" ~/.claude/skills/folio

# Invoke in Claude Code
/folio "My research idea" path/to/materials/
```

See [Getting Started](guides/getting-started.md) for full installation and first-run instructions.
