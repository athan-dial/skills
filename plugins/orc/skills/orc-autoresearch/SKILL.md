---
name: orc:autoresearch
description: >
  Autonomous optimization loop inspired by Karpathy's autoresearch pattern.
  Iteratively improve any measurable codebase metric (coverage, latency, accuracy, test pass rate)
  by observing misses, hypothesizing fixes, dispatching edits to Cursor/Codex, evaluating,
  and ratcheting gains via git. Use when: "orc:autoresearch", "autoresearch", "optimize X metric",
  "iterate until X improves", "hill-climb", "run the loop", "autoresearch on [target]",
  or when the user wants autonomous iterative improvement of a scalar metric.
  Part of the orc system: orc:plan, orc:backlog, orc:autoresearch, orc:status, orc:recap, orc:scope, orc:handoff.
---

# Orc: Autoresearch

Autonomous hill-climbing for any codebase metric. Opus orchestrates; Cursor/Codex execute; git ratchets gains.

## Commands

- `/autoresearch [description]` — Start new session (discovery + loop)
- `/autoresearch:status` — Read `var/autoresearch/<slug>/session.json`, display iteration, best metric, last hypothesis
- `/autoresearch:resume` — Read `session.json`, restore state, continue from last iteration. See `references/loop-integration.md`

## Phase 1: Discover (interactive)

Use AskUserQuestion (max 3 questions). Skip when args make the answer obvious.

1. **Metric**: Propose a scalar metric + evaluator command. Present as choice.
2. **Mutable scope**: Which files the loop may edit (propose 1-3). Can include "new files in X dir" for catalog enrichment.
3. **Guard command**: Detect from justfile/package.json/Makefile.

## Phase 2: Init (automated)

Run `bash scripts/init-session.sh <slug> <branch-name>`. The script:
- Creates `autoresearch/<slug>` branch
- Creates `var/autoresearch/<slug>/` directory
- Writes `allowed_files.txt`

Then:
1. Write `program.md` from `references/program-template.md`
2. Write `evaluate.sh` (must output JSON: `{"metric": N, "miss_report": {...}}`)
3. Run evaluator **twice** — if results differ > 0.1%, warn user (non-deterministic evaluator)
4. Save `baseline.json`, commit: `autoresearch(<slug>): init baseline=<metric>`

## Phase 3: Loop (autonomous via /loop)

Integrates with `/loop` for self-pacing. See `references/loop-integration.md` for session.json schema and resume protocol.

Each `/loop` tick = one **OHEE** iteration:

**Observe** — Read last `iteration-<N>.json` + `git log --oneline -5` + `hypotheses.jsonl`. Do NOT re-read full mutable files.

**Hypothesize** — Pick highest-leverage fix from miss report. Check `hypotheses.jsonl` to avoid repeats. Log hypothesis.

**Experiment** — Route by size: trivial (<20 LOC) → Claude direct, focused (<100 LOC) → Cursor, complex → Codex. After executor completes, run `bash scripts/check-allowed-files.sh <slug>` to verify scope.

**Evaluate** — Run `bash scripts/ratchet.sh <slug>`. The script runs guard, evaluator, compares, and either commits or resets. Returns JSON with keep/revert decision + new metric.

### Convergence (any triggers exit)

- **Plateau**: Rolling 5-iteration window with net gain < threshold (default 1pp)
- **Max iterations**: 20 (configurable in program.md)
- **Target reached**: Metric meets goal
- **Exhaustion**: Proposed hypothesis already in hypotheses.jsonl

## Phase 4: Report

Write `var/autoresearch/<slug>/REPORT.md`. Display summary: baseline → final, top gains, plateau point.

Offer: merge `autoresearch/<slug>` branch (squash) or keep as-is.

## Hard Rules

- Never edit evaluator or guard during the loop
- Never edit files outside mutable scope (enforced by `check-allowed-files.sh`)
- One focused change per iteration
- All work on `autoresearch/<slug>` branch — never commit directly to main
- Git commit successes, git reset failures
- Read `hypotheses.jsonl` before proposing — no repeat experiments

## References

- `references/architecture.md` — Three-file pattern, orchestrator/executor split, miss report design
- `references/program-template.md` — Template for program.md
- `references/loop-integration.md` — /loop self-pacing, session.json schema, resume protocol
