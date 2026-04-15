# Folio

Claude Code skill pack for end-to-end research paper orchestration.

## Project Structure

```
SKILL.md              — Main skill entry point (Claude Code loads this)
skills/               — Sub-skill SKILL.md files (init, prep, plan, support, draft, review, export, status)
references/           — Install, workflow, and failure-mode docs
references/modes/     — Mode-specific guidance (white-paper, research-paper, hybrid)
scripts/              — Deterministic helper scripts (Python + shell)
templates/            — Workspace layout templates and manifest schemas
```

Workflow scripts include `classify_materials.py` (materials typing), `route_mode.py` (mode selection and confidence), `scan_redlines.py` (IP/redline checks against `ip_policy.json`), and `package_exports.py` (export bundles).

The skill supports three modes: **white paper** (narrative / positioning), **research paper** (empirical / LaTeX-forward), and **hybrid** (combined framing and evidence). Mode follows routing after prep; users can override when routing is ambiguous.

## Conventions

- All workflow state lives in a `workspace/` directory created per project.
- Artifacts are markdown, JSON, BibTeX, or LaTeX — no binary blobs except figures.
- Helper scripts are invoked by the skill via `Bash` tool, not imported as libraries.
- Every script exits non-zero on validation failure with a human-readable message.
- The skill pauses for human approval at three checkpoints: after prep, after planning, before final export.

## Development

- Python scripts target 3.10+ with no external dependencies beyond stdlib.
- `compile_package.sh` requires `pdflatex` and `bibtex` on PATH (optional — skill degrades gracefully).
- Test with: `cd plugins/folio && python scripts/validate_inputs.py workspace/` to check a workspace.
