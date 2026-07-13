---
name: research-run
description: Use for ML/research runs: configs, logs, metrics, ablations, seeds, reproducibility, result interpretation, improve/degrade/noise/broken verdicts.
---

# Skill: Research Run

## Purpose

Decide what a run result means and what to do next.

## Rules

- Separate hypothesis, run setup, metric, observed result, and conclusion.
- Do not compare runs unless data, code, eval, and metric are compatible.
- Do not treat one noisy seed as evidence.
- Prefer the cheapest check that reduces uncertainty.
- If run looks plausible but wrong, use `debug-ml-research`.

## Checklist

- What changed?
- What stayed fixed?
- What data/split?
- What metric/eval path?
- What seed(s)?
- What config/commit/log path?
- Is effect bigger than noise?
- Is there a simpler baseline/control?
- Does the objective's own optimum reach ground truth? Measure the oracle/ceiling before reading any recovery-vs-truth number.
- Across a budget/scale/size sweep, are both arms on the *sloped* part of their curves, not saturated at a floor/ceiling? Two saturated arms give an uninformative comparison — move to a regime where the axis still bites.

## Verdicts

- `improve`: valid comparison; effect exceeds expected noise.
- `degrade`: valid comparison; worse beyond expected noise.
- `noise`: movement within expected variance.
- `broken`: invalid run, metric, data, or code path.
- `unknown`: missing artifact prevents conclusion.

## Boundary

- This skill interprets run evidence and chooses the next check.
- If verdict is `broken` or the run is plausible-but-wrong, stop interpretation and hand off to `debug-ml-research`.

## Output

- Hypothesis:
- Evidence:
- Verdict:
- Caveats:
- Next check:

If the project keeps a `LOG.md` (`context-project-docs`), append the filled block there — append-only, one entry per run.

## Anti-Patterns

- Comparing across changed eval pipelines.
- Cherry-picking best seed.
- Treating one seed as robust.
- Reporting metric movement without variance/noise context.
- Training longer instead of checking broken assumptions.
- Reading recovery-vs-ground-truth without first checking the score's optimum IS the truth — a flat 0% recovery is usually a non-identifying objective (or a broken metric), not a failing method; no method comparison on that metric means anything until the ceiling is confirmed.
- Reading a verdict off a sweep point where both arms are saturated (floored/ceilinged) — the comparison is uninformative; pick a regime where the axis still moves the metric before comparing.

## Related Skills

- `debug-ml-research` for broken/plausible-wrong runs.
- `dev-viz` for figures/tables.
- `research-session` for project implications and idea triage.
