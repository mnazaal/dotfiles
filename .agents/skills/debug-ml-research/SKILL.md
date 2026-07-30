---
name: debug-ml-research
description: Use for silent ML research failures: code runs, loss changes, logs plausible, but experiment is wrong; data/loss/eval mismatch, overfit tiny data, synthetic recovery, convention bugs, leakage, diffusion/probabilistic failures.
---

# Skill: Debug ML Research

## Target Bug Class

Code runs, loss changes, logs look plausible, but the experiment is wrong.

## Diagnostic Ladder

1. Verify model optimizes intended objective.
2. Verify data and targets mean what you think.
3. Verify model can overfit trivial cases.
4. Verify method works on synthetic data with known answer.
5. Verify evaluation/sampling match training.
6. Verify method beats simple baselines.
7. Add research-code complexity back incrementally.

## Strip to Boring

- One seed, one device, one batch, one/few examples, small model.
- Deterministic order; no augmentation/dropout/distributed/mixed precision/EMA/accumulation/custom kernels.
- No scheduler unless being tested.

## Core Checks

- Tiny overfit: one example → two → one batch → fixed subset.
- Data meaning: alignment, label mapping, masks, padding, split integrity, normalization, coordinates, timesteps, conditioning.
- Loss meaning: perfect/random/wrong predictions, sign, mask before reduction, intended dimensions and scale.
- Conventions: logits/probs, variance/std/log-var, RGB/BGR, image scale, mask polarity, batch/event dims, EMA/raw weights.
- Gradients: intended params get finite nonzero grads, optimizer contains trainable params, LR/clipping/AMP not erasing signal.
- Synthetic recovery: generate from known params and recover params/latents/rule.
- Eval: preprocessing, mode, metrics, checkpoint reload, sampler parameterization, no leakage.
- Seed sweep: for a stochastic method never conclude from one seed — run several; a fix that rescues one seed can fail others (complementary failure modes), and one green seed is not recovery.
- Passing by side-effect: a change that makes the metric pass but that you cannot derive is unverified — it may pass via an unrelated side-effect (e.g. accidentally breaking a symmetry) and mask the real bug.
- Fidelity fix turns a green test red: the prior is that the test was calibrated against the bug, not that the fix broke the science. Derive what the *corrected* objective implies for the asserted quantity before "restoring" the metric — the old passing value may have been the bias. Converse of passing by side-effect.
- Nested-variant gain: a variant that *contains* the current model (an added edge or parameter, reproducible by setting it to zero) should gain ~½ nat of fitted log-likelihood. A large gain is misspecification — generator and scorer disagree about the model — not evidence for the variant. Check this before interpreting any model-comparison number.
- Converged baseline: before believing an effect measured by refitting, refit the *reference* configuration from known-good parameters. If that beats your baseline by the same order as the effect, you measured the optimizer, not the effect.
- Self-satisfying metric: include a tripwire baseline that *must* fail (e.g. a zero-width predictor scored for coverage); if it also "passes", the eval is self-consistent — truth sits at the center of its own prediction, or is averaged over items sharing one ground truth — and proves nothing. Coverage/calibration is a property over (parameter, data) draws (SBC), not over items within one fixed truth.

## Specialized Probes

- Probabilistic models: prior/posterior predictive, support constraints, Jacobians, event vs batch log-prob sums, calibration; pick the estimator from the derivation (e.g. log E[p] vs E[log p]), not from what makes a metric move — a mean-of-logs with a heavy tail is dominated by rare catastrophic draws.
- Optimization vs objective: when recovery fails, initialize the fit at the known/true answer. Stays there (stable, higher objective) ⇒ objective/estimator is right and the failure is optimization — fix init, add restarts selected by the objective, or break symmetry. Drifts away ⇒ the objective/estimator itself is wrong.
- Invariance sweep: for any sampler with a parameter that theoretically shouldn't shift the stationary target (e.g. a mixing/proposal rate, a temperature meant to only affect speed), sweep it and check the output distribution doesn't move. A shift usually means a state-pairing/off-by-one bug (e.g. weighting by the wrong event's holding time), not sampler noise.
- Latent-component identifiability: in mixture / latent-cell models the likelihood is invariant to permuting component labels, so a single MCMC chain can lodge in one labeling and silently mis-split mass between components — a per-component recovery metric then fails on *some* seeds only. Break the symmetry with a component-distinguishing prior (probe its strength: too weak still switches), run multiple chains, or align labels post-hoc. To prove a recovery test can even *detect* non-identifiability, sweep a knob from the identifiable regime to a known non-identifiable one and assert the posterior reverts to the prior rather than "recovering" mass from nothing.
- Diffusion: overfit one image, visualize noising, reconstruct `x0`, loss by timestep, epsilon/x0/v convention, sampler matches training objective.
- Conditioning: shuffle/zero/permute conditions; behavior should degrade or change meaningfully.
- Metric worsens with MORE budget/data/optimization: a monotone *degradation* as you add the resource that should help is rarely noise — suspect a scale/units mismatch in the decision rule (an arbitrary latent/utility scale combined with a fixed real-unit term; the fixed term goes negligible as the latent amplitude grows with data) or an acquisition pathology. Confirm with a natural experiment: a condition where the bug MUST vanish (e.g. an interior vs boundary optimum) and check it does.
- Threshold/penalty calibration along the path: to set a per-step threshold (sparsity penalty, acceptance cutoff, stopping rule) in a sequential build/search, measure the marginal quantity ALONG the actual operating trajectory (e.g. empty→solution build order), not only at the target/optimum. A threshold calibrated at the optimum can be off by a large factor from where the search operates, and if the marginal profile is non-monotone along the path, no constant threshold works — which the at-optimum measurement hides.

## Boundary

- Owns diagnosis of a run that completed and is wrong: the ladder, the probes, the conventions.
- Anything that crashes or errors has a symptom to reproduce — `debug-root-cause`. A failed *statistical* assertion (recovery threshold, calibration bound, metric bar) is not that: it reproduces trivially, and the open question is whether the asserted number was ever right. That is this skill — routing it to `debug-root-cause` burns the run budget re-observing a number nobody has justified.
- A run that is valid and merely disappointing is not broken; `research-run` decides what it means.
- Building the data path is `dev-ml-data`; this skill is what you reach for once a data bug already reached a run.
- Writing these checks as standing tests before the failure is `dev-tdd`.

## Related Skills

- `debug-root-cause` for crash-type bugs.
- `dev-ml-data` for building the data handling whose failures this skill diagnoses.
- `dev-jax` / `dev-pytorch` for framework-specific fixes.
- `research-run` for interpreting completed runs.
