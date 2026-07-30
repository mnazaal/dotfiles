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
  draw. **Then check what pairing actually removed.** A shared seed does not pair
  the arms if their code paths consume the RNG stream differently — one extra
  draw (an init one arm skips, an extra MH move) desynchronizes everything after
  it, so the arms differ by sampling path as well as by treatment. Symptom:
  per-seed differences much larger than the effect, which looks identical to a
  heavy-tailed effect (Checklist) but is nuisance, not unreliability — separate
  the two by reading the arms' RNG consumption, not the numbers. Where it holds
  only the mean over many seeds is readable: never quote a per-seed or few-seed
  difference, and size N from the *paired* sd rather than assuming pairing
  removed it.
- **Pick a regime where the axis still bites.** Two arms saturated at a floor or
  ceiling give an uninformative comparison however many seeds you spend on it.
- **Measure the oracle before building the comparison.** Put the ceiling arm —
  true graph, true parameters, whatever the objective's own optimum is — through
  the identical eval path first, and report every arm as excess over it. Without
  the floor you cannot tell an arm difference from pipeline error, and arms that
  all sit far above it are measuring the pipeline, not the method. Reading this
  off the checklist afterwards is too late; the design is already spent.
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
- Does the mean difference agree with the median and the win-rate? A significant mean with a near-zero median and a ~50% win-rate is a heavy-tailed effect: a few cases moved far in *both* directions. Report median, win-rate and the tail beside the mean, and word the finding as unreliability rather than a shift.
- Is there a simpler baseline/control?
- Is each baseline the reference/established implementation (wired via an adapter), or one we reimplemented? A self-coded comparator can be subtly weak in ways that inflate our method's gain — prefer the authors'/library code behind an adapter (isolated env if it needs legacy deps; patch only runtime-compat, never the algorithm, and record the patches).
- Does the objective's own optimum reach ground truth? Measure the oracle/ceiling before reading any recovery-vs-truth number.
- What condition would force this effect to zero, and has it been run? Every mechanism implies a null-control — an arm where the claimed *cause* is structurally absent (latent made irrelevant, signal removed, knob at its no-op value). Distinct from the oracle, which bounds what is *achievable*: this bounds what the mechanism *explains*. An effect that survives its own null-control is either more general than the story attached to it, or an artifact of the comparison, and nothing else in the sweep separates those. Unlike the oracle it stays repairable after the fact — usually one extra cell.
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
- Reading a flat/invariant sweep as "the axis doesn't matter" without running the axis's null point. If the effect is unchanged where its supposed cause is absent, the mechanism story is wrong even when every cell is individually significant.
- Calling a non-significant result "no effect" (or accepting a pre-registered null) without a power check — under-powered or confounded non-significance is inconclusive, not evidence of absence.
- Comparing against a baseline we reimplemented when the authors'/established implementation exists and could be run via an adapter — a hand-rolled comparator that underperforms flatters the method.

## Related Skills

- `debug-ml-research` for broken/plausible-wrong runs.
- `dev-viz` for figures/tables.
- `research-session` for project implications and idea triage.
