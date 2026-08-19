---
name: dev-tdd
description: Use for test-first development: features, bug fixes, regression tests, red-green-refactor, public-interface behavior tests, small vertical slices, seams for I/O and dependencies.
---

# Skill: Dev TDD

## Rules

- Test behavior through public interfaces, not private implementation details.
- Prefer one observable behavior per test/check.
- Make the check able to fail for the right reason.
- Validate numerics against an independent oracle (exact enumeration, finite differences, analytic special case), not a re-derivation of the code's own formula.
- For stochastic recovery, assert a distribution (e.g. median over seeds), not a single-seed threshold — a lucky seed hides seed-dependent failure.
- Golden/snapshot first run is red because it writes the baseline — re-run to confirm, don't debug it as a failure.
- Regenerate a snapshot deliberately when an input changes; review the diff, never blind-accept `--force-regen`.
- Time a new test before assigning its speed marker — a property/fuzz-style check can look fast by design but run slow in practice (e.g. per-call retracing in a loop); don't guess.
- In greenfield suites or explicit project-policy changes, deselect the slow tier by default so the routine command is the fast gate: set `addopts = "-m 'not slow'"` in pyproject and run slow tests explicitly (`pytest -m slow`) or in CI. Do not override an existing project's test policy casually; ensure the excluded tier has an explicit verification path.
- Write minimal code to pass; refactor only while green.
- Keep I/O and external dependencies behind seams.
- Do not batch tests ahead of implementation.
- Prefer tracer bullets: the thinnest end-to-end behavior that proves the path works (https://www.aihero.dev/tracer-bullets).
- Primary completion evidence is end-to-end: a test that exercises the real entry point (CLI, script, train step). Unit-test a piece in isolation only when its logic is tricky enough to earn it; unit-green alone never proves the pipeline. For ML pipelines the standing form is `dev-ml-infra`'s smoke run.
- Prefer vertical slices over horizontal slices; cut through the needed layers for one behavior instead of completing one layer for all behaviors.

## Workflow

1. Pick one behavior; for new features, start with the smallest tracer bullet.
2. Write one red-capable test/check.
3. Run or reason about expected failure.
4. Implement only enough code to pass.
5. Run focused verification.
6. Refactor only while green.
7. Repeat with the next behavior.

## What Earns a Characterization Test

Not all code repays pinning. Spend the effort where being subtly wrong is
silently critical, because that is the class where nothing fails loudly:

- Losses, log-probs, samplers, transforms and their Jacobians, custom gradients,
  normalizations, numerical kernels.
- Data and eval paths that could leak or misalign labels (`dev-ml-infra`).
- Public API, CLI, and serialization — anything defining an external contract or
  able to silently corrupt stored data.

Below that: code with real behavior that is shallow to verify or fails loudly
gets a contract test. Code with no meaningful behavior or external contract —
cosmetic plotting, logging, repr-only — gets neither; leave it alone.

Pin behavior with a characterization test BEFORE changing it, so an improvement
pass cannot alter behavior silently.

## ML Test Types

Standing tests for ML code — the proactive form of `debug-ml-research`'s checks; write them before the failure, not after. Check details live there, not here:

- From the `debug-ml-research` ladder, as standing regression tests: tiny-overfit, synthetic recovery (median over seeds, per the stochastic rule above), gradient flow, invariance/equivariance, leakage and train/eval parity.
- Loss-at-init sanity: initial loss matches theory (≈ log C for C-class cross-entropy); catches broken losses/labels at step 0.
- Shape/dtype: `jaxtyping` annotations with runtime checking on public functions double as tests; add explicit cases only for tricky broadcasting.
- E2E: the `dev-ml-infra` smoke run through the real entry point is the standing pipeline gate.

## Anti-Patterns

- Tests after large implementation batches.
- Horizontal slicing: all tests first, all implementation later, or layer-only work that cannot be verified end-to-end.
- Testing mocks instead of behavior.
- Broad golden tests that fail opaquely.

## Boundary

- Owns the red-green-refactor loop and what a test should assert.
- It does not certify completion — a green suite is not evidence a claim holds; `dev-verification` owns that gate.
- The content of the ML checks lives in `debug-ml-research`; this skill owns writing them before the failure rather than after.
- The standing pipeline gate is `dev-ml-infra`'s smoke run, not a unit test written here.
- Chasing a failure whose cause is unknown is `debug-root-cause`, not another test.

## Related Skills

- `dev-python` for Python test/tool conventions.
- `debug-ml-research` for the reactive form of the ML checks above.
- `debug-root-cause` when failure cause is unknown.
- `dev-verification` before declaring done.
