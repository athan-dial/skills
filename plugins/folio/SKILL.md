---
name: folio
description: "End-to-end manuscript orchestration — white paper, research paper, or hybrid mode. Runs the full pipeline from raw materials to exportable manuscript, or resumes from the last checkpoint. Sub-commands available: /folio:init, /folio:prep, /folio:plan, /folio:support, /folio:draft, /folio:review, /folio:export, /folio:status"
trigger: /folio
---

# Folio — Claude Code Skill

Artifact-driven manuscript orchestration engine. Supports three modes — **white paper**, **research paper**, and **hybrid** — with deterministic gates, auditable artifacts, and human checkpoints at every risky transition.

## Core Principles

1. **Artifacts before prose** — Build reliable intermediate artifacts before composing long-form text.
2. **Prep is first-class** — Never assume pristine inputs; normalize, classify, and route before drafting.
3. **Deterministic gates beat eloquent mistakes** — Unsupported claims, broken refs, and policy violations fail loudly.
4. **Humans approve risky transitions** — Pause after prep, after planning, and before final export.
5. **One coherent workflow with branching modes** — Same spine (init → prep → route → mode stages → package); modes differ only where artifact contracts differ.
6. **IP safety is non-negotiable** — Every mode runs redline scanning; violations block until resolved or explicitly acknowledged.

## Invocation

```
/folio [idea] [materials_path]    — Start new project
/folio workspace/                 — Resume from last checkpoint
```

## Commands

| Command | Stage | What it does |
|---------|-------|--------------|
| `/folio:init` | 0 | Initialize workspace, collect intent |
| `/folio:prep` | 1 | Normalize, classify, route + **Checkpoint 1** |
| `/folio:plan` | 2 | Mode-specific planning + **Checkpoint 2** |
| `/folio:support` | 3 | Evidence, literature, figures (research/hybrid) |
| `/folio:draft` | 4 | Compose manuscript |
| `/folio:review` | 5 | IP scan, review, repair |
| `/folio:export` | 6 | Finalize, compile, package + **Checkpoint 3** |
| `/folio:status` | — | Show pipeline state |

## Mode–Stage Map

| Stage | White Paper | Research Paper | Hybrid |
|-------|-------------|----------------|--------|
| 0 Init | ✓ | ✓ | ✓ |
| 1 Prep | ✓ | ✓ | ✓ |
| 2 Plan | W2–W3 | D2 | H2 |
| 3 Support | — | D3 | H3 |
| 4 Draft | W4 | D4 | H4 |
| 5 Review | W5 | D5 | H5 |
| 6 Export | W6 | D6 | H6 |

## Orchestration Logic

When invoked as `/folio`:

1. **No workspace arg** — Run `/folio:init`, then chain through all stages sequentially.
2. **Workspace arg** — Read `logs/checkpoints.md`, find last completed stage, resume from next.
3. **After each stage** — Check gate pass before advancing. If gate fails, halt and report.
4. **Human checkpoints** — Pause and wait for explicit approval before continuing. Never auto-advance past a checkpoint.

Display resumption state as:

> **Workspace:** `<path>` | **Mode:** `<mode>` | **Last completed:** `<stage>`
> **Next:** `<stage>` — `<description>`
> Say **continue**, **redo \<stage\>**, or **change mode to \<mode\>**.

## Scripts Quick Reference

| Script | Purpose | Stage |
|--------|---------|-------|
| `init_workspace.py` | Create workspace tree and seeds | 0 |
| `prep_materials.py` | Scan / prep materials inventory | 1 |
| `classify_materials.py` | Write `materials_passport.json` | 1 |
| `route_mode.py` | Write `route.json` (mode + confidence) | 1 |
| `validate_inputs.py` | Validate canonical inputs | 1 |
| `build_claim_ledger.py` | Validate / build claim ledger | 2–3 |
| `check_artifacts.py` | LaTeX cite/ref integrity | 4–5 |
| `scan_redlines.py` | IP / policy redline scan | 5 |
| `compile_package.sh` | PDF compilation (pdflatex/bibtex) | 6 |
| `package_exports.py` | Assemble `final/` bundle | 6 |

Run all scripts via the **Bash** tool from the `skills/` repo root by prefixing invocations with `cd plugins/folio && ...`. Python targets **3.10+**, stdlib only.

## References

| Topic | Path |
|-------|------|
| Gate details | `references/gates.md` |
| White paper mode | `references/modes/white-paper.md` |
| Research paper mode | `references/modes/research-paper.md` |
| Hybrid mode | `references/modes/hybrid.md` |
| Failure modes | `references/failure-modes.md` |
| Stage flow | `references/workflow.md` |
| Manifest schemas | `templates/manifests/*.schema.json` |

## Global Rules

**Logging discipline** — Every session appends to `logs/run_log.md` (decisions, overrides, failures) and `logs/checkpoints.md` (stage completion rows). This enables deterministic resume.

**Forbidden behaviors:**
- Skipping `scan_redlines.py` before declaring review complete
- Proceeding past IP gate with unaddressed violations without logged user decision
- Inventing citations or figures not in verified pools
- Mixing up workspace roots across commands

**Resume protocol** — On re-invocation, read `route.json` for effective mode, `logs/checkpoints.md` for last completed stage, and offer to resume, redo, or change mode. If the user requests a mode change, update `route.json` `user_override` and log the change.

---

*End of Folio skill definition.*
