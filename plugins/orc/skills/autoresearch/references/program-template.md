# Program: {{session_slug}}

## Objective

Maximize **{{metric_name}}** on {{target_description}}.

Current baseline: {{baseline_value}}
Target: {{target_value}} (or plateau)

## Mutable Scope

Only these files may be edited during the loop:

{{#each mutable_files}}
- `{{this}}`
{{/each}}

## Evaluator

```bash
bash var/autoresearch/{{session_slug}}/evaluate.sh
```

Output format: `{"metric": <number>, "miss_report": {"<category>": <count>, ...}}`

The evaluator is **locked** — never edit it during the loop.

## Guard

```bash
{{guard_command}}
```

Must pass after every edit. Failure = automatic revert.

## Levers (ordered by expected impact)

1. {{lever_1}} — {{lever_1_rationale}}
2. {{lever_2}} — {{lever_2_rationale}}
3. {{lever_3}} — {{lever_3_rationale}}

Prioritize levers in this order. Exhaust high-impact categories before moving to lower ones.

## Constraints

- One change per iteration
- Do not edit the evaluator or guard logic
- Do not edit files outside mutable scope
- Do not add dependencies without user approval
- If a hypothesis was already tried (check hypotheses.jsonl), skip it

## Convergence

- **Plateau threshold**: {{plateau_threshold}} (default: 1pp over 3 consecutive iterations)
- **Max iterations**: {{max_iterations}} (default: 20)
- **Target**: {{target_value}} (stop early if reached)

## Context

{{context_notes}}
