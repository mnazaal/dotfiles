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

## Specialized Probes

- Probabilistic models: prior/posterior predictive, support constraints, Jacobians, event vs batch log-prob sums, calibration; pick the estimator from the derivation (e.g. log E[p] vs E[log p]), not from what makes a metric move — a mean-of-logs with a heavy tail is dominated by rare catastrophic draws.
- Optimization vs objective: when recovery fails, initialize the fit at the known/true answer. Stays there (stable, higher objective) ⇒ objective/estimator is right and the failure is optimization — fix init, add restarts selected by the objective, or break symmetry. Drifts away ⇒ the objective/estimator itself is wrong.
- Invariance sweep: for any sampler with a parameter that theoretically shouldn't shift the stationary target (e.g. a mixing/proposal rate, a temperature meant to only affect speed), sweep it and check the output distribution doesn't move. A shift usually means a state-pairing/off-by-one bug (e.g. weighting by the wrong event's holding time), not sampler noise.
- Diffusion: overfit one image, visualize noising, reconstruct `x0`, loss by timestep, epsilon/x0/v convention, sampler matches training objective.
- Conditioning: shuffle/zero/permute conditions; behavior should degrade or change meaningfully.

## Related Skills

- `debug-root-cause` for crash-type bugs.
- `dev-jax` / `dev-pytorch` for framework-specific fixes.
- `research-run` for interpreting completed runs.
