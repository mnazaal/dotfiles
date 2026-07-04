---
name: dev-jax-port
description: Use for porting a reference ML implementation (e.g. PyTorch/Lightning) or scientific/optimization algorithm (NumPy/SciPy) to JAX: sample-replay parity testing, weight/state conversion to pytrees, bottom-up layer-by-layer verification, numerical-equivalence debugging, float32 vs float64 conditioning, choosing jax.nn vs Equinox.
---

# Skill: Dev JAX Port

## Iron Law

Parity, not plausibility. A port is correct only when it reproduces the reference's outputs, gradients, and post-update weights on identical inputs and state. Never claim correctness because the code "looks equivalent."

## Rules

- The reference implementation is ground truth; the JAX port matches it, not the reverse. (Reference is commonly PyTorch but need not be.)
- A reference's silent clamp/truncate-behind-a-warning is not worth porting faithfully — warnings don't survive tracing/jit anyway. Replace it with an eager, explicit error at the port's entry point.
- Check the reference's own test suite and code comments, not just its main source, before trusting a source-only reading. Subtle semantic invariants (e.g. pre-event vs. post-event state in an event-driven simulation, which array a weight pairs with) are sometimes documented only in a test docstring or comment, never restated in the implementation itself.
- A byte-identical top-level diff against the reference is not parity evidence if that function delegates to a differently-implemented helper — trace the full call chain. Where two implementations reach the same well-defined operation via different algorithms, one recorded trace does not establish agreement; fuzz-check across many randomly generated valid inputs instead.
- Default to plain `jax.nn` (+ Optax). Reach for Equinox only when the architecture is complex enough that hand-rolling modules is error-prone; reuse a library rather than reimplement from scratch.
- Drop config/training frameworks (Hydra, Lightning) inside the port; use plain dataclasses and explicit functions. The experiment layer wrapping a finished port may use hydra-zen (`dev-ml-infra`) — keep it out of the parity-tested core.
- Verify bottom-up: each layer parity-passes before building the one above it (weights → modules → pure ops → state/env → loss → train step).
- Drive the JAX side by replaying recorded reference decisions (sampled actions, dropout masks, RNG draws), never by re-sampling; this isolates implementation diff from stochastic diff.
- Record from one reference run: initial weights/state, the batch, every stochastic choice, per-step intermediates (forward outputs, rewards/energies, masks), final loss, gradients, and post-optimizer weights.
- Convert weights explicitly with a name→pytree-leaf map; assert shape on every load. Mind layout differences (linear weight orientation, conv layouts, fused gates).
- Set a tolerance policy per quantity: forward/loss tight in the production dtype; gradients/weights checked where parity is actually defined (see float64 rule).
- Match reduction and accumulation order exactly. Loss accumulation, masking, softmax-weighting, and `mean` placement change both values and gradients.
- Match autograd boundaries exactly: every `.detach()`/`stop_gradient`, and in-place index-assign vs `.at[...].set()`.
- Keep compute functions dtype-faithful (created arrays follow input dtype) so float32 and float64 paths stay isolated under `jax_enable_x64`.

## Workflow: Neural Network Port (PyTorch → JAX)

1. Scout the reference module: entry point, forward, loss, optimizer step, RNG/sampling sites. Route to `dev-scout`.
2. Decide the mapping: `jax.nn` by default (Equinox only for complex architectures), Optax for optimizers, dataclasses for config. Confirm target dtype.
3. Build the recorder: run the reference once, monkeypatch samplers to capture decisions, save a replay bundle (weights, batch, decisions, intermediates, loss, grads, updated weights). Add a float64 reference pass that replays the same decisions for gradient/weight references.
4. Write the weight converter (reference params → pytree); parity-test it on shapes and values.
5. Port and parity-test each layer bottom-up, one at a time, before moving up.
6. Port the loss; match accumulation order and autograd boundaries; parity-test against the recorded loss.
7. Port the train step (single Optax update); parity-test gradients and post-update weights.
8. Verify the full suite, then state results with evidence. Route to `dev-verification`.

## Workflow: Optimization Algorithm Port (NumPy/SciPy → JAX)

For scientific algorithms (structure learning, constrained optimization, MCMC kernels) where the reference is NumPy/SciPy, not a neural net:

1. Scout the reference: identify each mathematical primitive (reshape, constraint function, objective), the optimization loop, and the output structure.
2. Confirm target dtype. Scientific algorithms typically need x64; set `jax.config.update("jax_enable_x64", True)` before any array creation.
3. Port and parity-test bottom-up — primitives first, then objective, then gradients, then full convergence:
   - **Primitives**: port each pure mathematical function (reshapes, constraint, regularization terms); verify against reference on fixed random inputs with `assert_allclose(rtol=1e-10)`.
   - **Objective**: reconstruct the full scalar loss in JAX; verify value matches reference at multiple `(x, hyperparams)` points.
   - **Gradients**: compute `jax.grad(objective)` and verify against finite differences (`eps=1e-5`, central differences) with `rtol=1e-3, atol=1e-5`. This is the primary check that autograd is wired correctly.
   - **Full convergence**: run both implementations from identical initialization with the same hyperparameters; compare final solutions with loose tolerance (`rtol=1e-2, atol=5e-3`) — optimization paths may diverge slightly due to floating-point order.
4. Test determinism: run twice from the same initialization; assert bit-exact outputs (`rtol=0`).
5. Test constraint satisfaction: verify the domain-specific correctness criterion (e.g. h(W) ≤ tol for DAG constraint) independently of the reference comparison.
6. Test input validation: error handling should match the reference exactly.
7. Verify the full suite. Route to `dev-verification`.

## Numerical-Equivalence Debugging

- A clean, systematic mismatch (constant factor on one row/channel, signs agreeing) is a real signal, not "framework noise." Investigate before adjusting anything.
- Localize: compare per-layer then per-row/channel; find the smallest mismatching quantity.
- Distinguish bug from conditioning: recompute the disputed value in float64 on both sides, and/or finite-difference the JAX loss. If float64 agrees to ~1e-6 while float32 disagrees, it is float32 conditioning (e.g. catastrophic cancellation from a low-temperature near-one-hot softmax), not a port bug.
- Fix the cause, not the bar: check gradient/weight parity at float64 against float64 references; keep float32 for the forward/loss production path.
- Route unknown root causes to `debug-root-cause`; route silent, plausible-but-wrong runs to `debug-ml-research`.

## Anti-Patterns

- Widening tolerance, skipping, or deleting an assertion to make parity pass.
- For optimization algorithm ports: skipping the finite-difference gradient check and only comparing final solutions — convergence parity is necessary but not sufficient; autograd can be silently wrong if a primitive is not differentiable through.
- For optimization algorithm ports: comparing only at zero initialization — primitives that are correct at zero can still be wrong at nonzero due to reshape or indexing bugs.

## Related Skills

- `dev-pytorch` for reference-side idioms when the source is PyTorch; `dev-jax` for target-side idioms (jax.nn/Equinox/Optax choices).
- `dev-scout` to map the source module first.
- `dev-tdd` for the red-green parity-test loop; `dev-verification` before completion claims.
- `debug-root-cause` for parity failures of unknown cause; `debug-ml-research` for silent ML wrongness.
