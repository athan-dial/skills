# Autoresearch Architecture

## Three-File Pattern

Derived from Karpathy's autoresearch (March 2026). The constraint is the engine: bounding the search space makes every experiment reviewable and comparable.

### program.md (strategy — human only)

The bridge between human intent and agent tactics. Defines:
- What metric to optimize
- Which levers to try (ordered by expected impact)
- What NOT to change
- When to stop

The agent reads it at the start of each session, then references only the evaluator output for subsequent iterations.

### Mutable file(s) (the "train.py")

The only code the executor may edit. Keep the scope tight:
- 1-3 files is ideal
- More than 5 files means the session is too broad — split into sub-sessions

### Evaluator (locked — never edited by the loop)

Must produce a deterministic, single-line JSON output:
```json
{"metric": 51.2, "miss_report": {"caps_suffix": 15, "parenthetical": 8, "not_in_catalog": 42, "modality_description": 12}}
```

The miss report is what makes this better than a naive loop. By categorizing failures, the strategist (Opus) knows which lever to pull next instead of guessing.

## Orchestrator/Executor Split

The key insight from community implementations: **reasoning about state** stays in Opus; **modifying state** goes to Cursor/Codex.

### Opus (orchestrator)
- Reads evaluator output (~1K tokens)
- Reads git log of last 5 iterations (~200 tokens)
- Hypothesizes the next fix (~200 tokens)
- Writes a strategy string for the executor
- Reviews the executor's diff
- Runs evaluator and decides keep/revert

### Cursor/Codex (executor)
- Receives: hypothesis, file paths, patterns, exclusions
- Edits the mutable files
- Runs guard command
- Returns: diff summary

After the executor finishes, its entire context is discarded. Only the diff and guard result flow back to Opus. This is how you stay under ~2K Opus tokens per iteration.

## The Ratchet

Git as episodic memory:
- Success → commit with structured message: `autoresearch(<slug>): iter N +Xpp <summary>`
- Failure → `git reset --hard HEAD~1`

The codebase only ever accumulates validated gains. The agent reads `git log` to avoid repeating failed experiments.

## Convergence Detection

From community implementations, ordered by sophistication:

1. **Hard budget**: Stop after N iterations (default: 20)
2. **Plateau**: 3 consecutive iterations with < threshold improvement (default: 1pp)
3. **Target**: Metric reaches the goal defined in program.md
4. **Exhaustion**: Agent proposes a hypothesis it already tried (check hypotheses.jsonl)
5. **Guard instability**: More than 50% of recent iterations fail the guard

## Executor Routing

Use the same routing rules as `/orchestrate`:

| Task shape | Route to | Why |
|-----------|----------|-----|
| Config change, synonym addition, < 20 LOC | Claude direct | Zero dispatch overhead |
| Single-file edit, < 100 LOC | Cursor | Fast, focused |
| Multi-file, > 100 LOC, new file creation | Codex | Stronger reasoning |

Bias toward Claude direct for well-specified hypotheses. The program.md already has the spec — just execute it. External agents add latency (~1-3 min) that compounds over 20 iterations.

## Miss Report Design

The evaluator's miss report is the highest-leverage design decision. A good miss report:

1. **Categorizes failures by fixable type** — not just "N unresolved"
2. **Separates actionable from structural** — "CAPS suffix" is fixable; "not in catalog" may require external data
3. **Counts per category** — so the strategist picks the biggest bucket first
4. **Includes 3-5 examples per category** — so the executor knows the pattern

Example:
```json
{
  "metric": 51.2,
  "miss_report": {
    "caps_corporate_suffix": {"count": 15, "examples": ["KAKEN PHARMA CO LTD", "CODIAK BIOSCIENCES INC"]},
    "parenthetical_brand": {"count": 8, "examples": ["Dupilumab (DUPIXENT)", "Romilkimab (SAR156597)"]},
    "not_in_catalog": {"count": 42, "examples": ["Phlebiarubrone derivatives", "BMSCs"]},
    "comma_separated": {"count": 3, "examples": ["lodash, underscore", "react, preact"]}
  }
}
```

The strategist reads this and knows: comma_separated is 3 items, easy fix, do it first. caps_corporate_suffix is 15, medium fix. not_in_catalog is 42 but requires external data — skip until other levers are exhausted.
