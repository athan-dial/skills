# /loop Integration

## Self-Pacing via /loop

Autoresearch uses Claude Code's `/loop` (dynamic self-pacing mode) for iteration control. Each `/loop` tick = one OHEE iteration.

Start: `/loop /autoresearch [description]`

The first tick runs Phase 1 (Discover) + Phase 2 (Init). Subsequent ticks run one Phase 3 iteration each. On convergence, the final tick runs Phase 4 (Report) and exits the loop.

## session.json Schema

```json
{
  "slug": "api-latency-opt",
  "branch": "autoresearch/api-latency-opt",
  "iteration": 7,
  "best_metric": 62.3,
  "baseline_metric": 48.1,
  "status": "running",
  "plateau_count": 0,
  "created_at": "2026-04-14T12:00:00Z",
  "last_iteration_at": "2026-04-14T12:35:00Z",
  "config": {
    "metric_name": "entity_coverage_pct",
    "guard_command": "just test",
    "evaluator": "bash var/autoresearch/api-latency-opt/evaluate.sh",
    "max_iterations": 20,
    "plateau_threshold": 1.0,
    "plateau_window": 5,
    "target_metric": null,
    "allowed_files": ["src/api/handler.py", "src/api/middleware.py"]
  }
}
```

## Resume Protocol (/autoresearch:resume)

1. Find active session: `ls var/autoresearch/*/session.json`, pick the one with `status != "complete"`
2. Read `session.json` — restore slug, branch, iteration count, best metric
3. `git checkout <branch>` if not already on it
4. Read last `iteration-<N>.json` for miss report context
5. Read `hypotheses.jsonl` for tried hypotheses
6. Continue the OHEE loop from iteration N+1

## Convergence via Rolling Window

Track the last 5 iteration deltas. If the **net gain** over the window is below `plateau_threshold`, trigger convergence.

This handles oscillation (+2, -1, +2, -1) better than "3 consecutive non-improving" because net gain over 5 iterations = +2, which is still improving. True plateau: (+0.3, +0.1, +0.2, -0.1, +0.0) → net = +0.5 < 1pp → stop.

Update `plateau_count` in session.json:
- After each iteration, compute rolling window net gain
- If below threshold, increment `plateau_count`
- If `plateau_count >= 1`, stop (single rolling-window check suffices because the window already aggregates)

## Status Display (/autoresearch:status)

Read session.json + last iteration JSON, display:

```
Autoresearch: api-latency-opt
  Branch: autoresearch/api-latency-opt
  Iteration: 7/20
  Metric: 62.3% (baseline 48.1%, +14.2pp)
  Last: +1.2pp (strip parenthetical brand names)
  Plateau: no (rolling 5-iter net: +4.8pp)
  Hypotheses tried: 7 (5 kept, 2 reverted)
```
