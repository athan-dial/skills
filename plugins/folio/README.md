# Folio

A Claude Code skill pack that converts research ideas and messy materials into validated, reviewable, exportable manuscripts through artifact-driven orchestration.

## What it does

Folio runs an end-to-end paper-writing workflow inside Claude Code:

1. **Prep** — Normalizes loose notes, PDFs, figures, and experiment results into canonical artifacts
2. **Plan** — Generates an outline, claim ledger, figure plan, and literature plan
3. **Support** — Builds citation pool, figures/tables, and evidence inventory
4. **Draft** — Composes an integrated manuscript from structured artifacts
5. **Review** — Critiques, refines, and reverts if quality drops
6. **Export** — Assembles final LaTeX package with bibliography and figures

Human checkpoints pause the workflow after prep, after planning, and before final export.

## Modes

Folio branches into three modes after prep and routing:

- **White paper** — Perspectives-driven narrative, Markdown-first draft, executive-oriented export.
- **Research paper** — Planning and evidence support, LaTeX draft, traditional finalize and package.
- **Hybrid** — Conceptual framing plus evidence support, merged draft, dual review, combined export.

`route_mode.py` recommends a mode from your materials; you confirm or override at the routing checkpoint.

## Install

Copy this repo into your Claude Code skills directory:

```bash
# From your Claude Code config directory
cp -r /path/to/folio ~/.claude/skills/folio
```

Or symlink it:

```bash
ln -s /path/to/folio ~/.claude/skills/folio
```

Then invoke with `/folio` in Claude Code.

## Usage

```
/folio [idea] [materials_path]
```

- **idea** — A sentence or paragraph describing the paper's core contribution
- **materials_path** — Path to a folder containing research materials (notes, data, figures, PDFs)

Both are optional. The skill will prompt for missing information interactively. After prep, say which mode you want (white paper, research paper, or hybrid) if the default routing does not match your intent.

## Requirements

- Claude Code
- Python 3.10+ (for validation scripts)
- `pdflatex` + `bibtex` on PATH (optional — for PDF compilation)

## Structure

```
SKILL.md              — Main skill definition
references/           — Install, workflow, and failure-mode documentation
scripts/              — Deterministic helper scripts (Python + shell)
templates/            — Workspace layout and manifest schemas
```

## License

MIT
