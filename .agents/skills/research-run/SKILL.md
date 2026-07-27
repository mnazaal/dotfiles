---
name: research-run
description: Use for ML/research runs at both ends. Before launching — designing a sweep or ablation, how many seeds, sizing/powering a comparison, pairing arms, choosing the regime. After — configs, logs, metrics, ablations, seeds, reproducibility, result interpretation, improve/degrade/noise/broken verdicts.
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

## Before Launching

Design-time decisions that cannot be repaired afterwards. Settle these before
the sweep runs: no analysis rescues an underpowered or unpaired design, and the
cost of getting them wrong is the whole sweep.

- **Name the comparison of interest now.** The best cell of an ablation grid is
  biased upward by selection alone. Naming the comparison up front is what makes
  the number reportable later without a correction or a fresh seed set.
- **Size it.** For a two-arm comparison at conventional power, roughly
  `n ≈ 16σ²/Δ²` per arm, from pilot per-seed variance σ and the minimum
  difference Δ worth acting on. If you cannot state Δ, you cannot size the sweep
  — and a non-significant result from an unsized design is inconclusive, not
  evidence of no effect.
- **Pair on seed.** Run both arms on the SAME seeds and compare per-seed
  differences; that removes seed variance from the comparison and usually needs
  far fewer runs than unpaired arms. Pair wherever the arms share a data or init
  draw.
- **Pick a regime where the axis still bites.** Two arms saturated at a floor or
  ceiling give an uninformative comparison however many seeds you spend on it.
- **Estimate per-cell wall-clock before fanning out.** `dev-hpc` owns the
  cluster-side minimum and the batching that clears it.

## Checklist

- What changed?
- What stayed fixed?
- What data/split?
- What metric/eval path?
- What seed(s)?
- What config/commit/log path?
- Is effect bigger than noise?
- If non-significant: was the design ever powered for the minimum effect worth acting on (Before Launching)? Below that N the result is inconclusive, not "no effect".
- Were the arms paired on seed (Before Launching)? If not, the comparison carries seed variance it did not need to.
- Report an interval on the *difference*, not two point estimates. With few seeds prefer a paired-difference CI or a bootstrap over quoting each arm's mean ± std and eyeballing the overlap — non-overlapping error bars is not the same test, in either direction.
- Is there a simpler baseline/control?
- Is each baseline the reference/established implementation (wired via an adapter), or one we reimplemented? A self-coded comparator can be subtly weak in ways that inflate our method's gain — prefer the authors'/library code behind an adapter (isolated env if it needs legacy deps; patch only runtime-compat, never the algorithm, and record the patches).
- Does the objective's own optimum reach ground truth? Measure the oracle/ceiling before reading any recovery-vs-truth number.
- Across a budget/scale/size sweep, are both arms on the *sloped* part of their curves, not saturated at a floor/ceiling? Two saturated arms give an uninformative comparison — move to a regime where the axis still bites.
- How many comparisons produced this winner? If the comparison was not named before running (Before Launching), correct for the number of cells or confirm the winner on a fresh seed set before reporting the gap.

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

If the project keeps a `LOG.md` (`context-project-docs`), offer to prepend the filled block there using the canonical LOG ordering — newest entry at top, one entry per run.

## Anti-Patterns

- Comparing across changed eval pipelines.
- Cherry-picking best seed.
- Treating one seed as robust.
- Quoting each arm's mean ± std and reading overlap as the test. The quantity of interest is the difference and its own variance; overlapping bars can still be a significant paired difference, and non-overlapping bars are not automatically significant.
- Reporting the top cell of a sweep as the effect size without correcting for selection or confirming it on fresh seeds.
- Reporting metric movement without variance/noise context.
- Training longer instead of checking broken assumptions.
- Reading recovery-vs-ground-truth without first checking the score's optimum IS the truth — a flat 0% recovery is usually a non-identifying objective (or a broken metric), not a failing method; no method comparison on that metric means anything until the ceiling is confirmed.
- Reading a verdict off a sweep point where both arms are saturated (floored/ceilinged) — the comparison is uninformative; pick a regime where the axis still moves the metric before comparing.
- Calling a non-significant result "no effect" (or accepting a pre-registered null) without a power check — under-powered or confounded non-significance is inconclusive, not evidence of absence.
- Comparing against a baseline we reimplemented when the authors'/established implementation exists and could be run via an adapter — a hand-rolled comparator that underperforms flatters the method.

## Related Skills

- `debug-ml-research` for broken/plausible-wrong runs.
- `dev-viz` for figures/tables.
- `research-session` for project implications and idea triage.
