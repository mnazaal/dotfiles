---
name: debug-root-cause
description: "Use for root-cause debugging: bugs, test failures, crashes, build failures, tool failures, unexpected behavior, flaky results, performance regressions, repro loops, hypotheses before fixes."
---

# Skill: Debug Root Cause

## Iron Law

No fixes without root-cause investigation or a stated blocker.

## Workflow

1. Capture exact symptom: command, output, expected vs observed, environment, recent changes. Read the lines ABOVE the headline error: a summary line is usually the consequence, the actionable error sits above it in different wording, and treating the headline as the whole error aims the next probe at the wrong layer.
2. If the failure surfaced right after your own edit/refactor, isolate your diff and rerun the same check before hypothesizing about the edit — cheap, conclusive, and rules out (or confirms) your change as the cause before you spend probes on it. Do not automatically `git stash`, reset, or check out another tree when staged hunks or unrelated user changes exist; get confirmation or use an isolated worktree/copy.
3. When it works in one environment and fails in another, run the SAME artifact in both and compare before theorising about which difference matters. Confined vs unconfined, container vs host, CI vs local: one comparison localises the fault to the boundary in a single step, and it is available before any hypothesis is.
4. Build a red-capable repro loop: command/check/artifact, exact symptom, expected vs observed, determinism or reproduction rate.
5. Minimize until remaining elements are load-bearing.
6. Generate ranked falsifiable hypotheses.
7. Probe one variable at a time; prefer targeted evidence over broad logging. Tag every debug log with a unique prefix (e.g. `[DEBUG-a4f2]`) so cleanup is one grep.
8. State root cause with confidence and evidence.
9. Hand off minimal fix plan to `dev-*` with regression-test seam.
10. Once the fix lands: re-run the original repro loop (must go green), grep and remove tagged debug instrumentation, and state the confirmed root cause in the commit/PR message.

## Building the Loop

Step 4 assumes a loop can be built. When none exists yet, build one before
hypothesising; the ways to do it, in the order to try them:

1. A failing test that pins the symptom.
2. A command-line invocation with a fixture input and a diff against the
   expected output.
3. Replay of one captured input — a request, a batch, a message — through the
   failing unit in isolation.
4. A throwaway harness that calls the suspect function directly with the
   recorded arguments.
5. A property or fuzz loop over many generated inputs, for "sometimes wrong".
6. A differential loop: old build against new, or suspect commit, seed, or
   config against its neighbour, on the same input.
7. A bisection harness over commits, and over data or config versions when
   the code did not change.
8. A hand-run script for what only the human can drive, printing `KEY=VALUE`
   lines at the end so the result comes back parseable.

Then tighten it along three axes: faster, sharper signal, more deterministic.
A thirty-second flaky loop is barely better than none; a two-second
deterministic one changes what is possible. The loop is done when one named
command, already run once, goes red on the symptom, is deterministic, is fast,
and can be run by the agent without the human.

The ML-specific loops — overfit one batch, synthetic recovery, replay one
batch through the step function — are `debug-ml-research`'s probe ladder;
this list is the general construction, and the levers apply to both.

## Reassessment Rules

- If first fix fails, stop and reassess the hypothesis before trying another fix.
- If three fixes fail, stop patching and map shared state, hidden coupling, environment, and assumptions.
- "Worked yesterday, fails today, code unchanged" means suspect state, not code: preprocessing or JIT caches, `uv.lock` against the actual `.venv`, a stale `results/` or hydra output directory, a half-written checkpoint. If clearing one restores the behavior, the root cause is the missing validation on that state, not the clear.
- Change one variable per probe unless explicitly testing an interaction.
- Keep symptom, hypothesis, probe, result, and next inference separate.
- For performance regressions, distrust logs — establish a baseline measurement first (timing harness, profiler, query plan), then bisect against it.
- For non-deterministic bugs, aim for a higher reproduction rate, not a clean repro — loop the trigger, parallelize, add stress, narrow timing windows until it's debuggable.

## Red Flags

- "Just try X" without evidence.
- Multiple fixes at once.
- Fixing symptom location instead of source.
- Hypotheses or fixes before a red-capable repro loop, unless blocked.
- Continuing without asking for artifacts/access when no loop is possible.
- Three failed fixes revealing new shared-state/coupling issues.
- Declaring root cause from plausible story instead of probe evidence.

## Related Skills

- `debug-ml-research` for silent ML failures.
- `dev-tdd` for regression tests.
- `dev-verification` before completion claims.
