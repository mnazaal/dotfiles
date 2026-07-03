---
name: debug-root-cause
description: Use for root-cause debugging: bugs, test failures, crashes, build failures, tool failures, unexpected behavior, flaky results, performance regressions, repro loops, hypotheses before fixes.
---

# Skill: Debug Root Cause

## Iron Law

No fixes without root-cause investigation or a stated blocker.

## Workflow

1. Capture exact symptom: command, output, expected vs observed, environment, recent changes.
2. If the failure surfaced right after your own edit/refactor, `git stash` (or check out the pre-edit tree) and rerun the same check before hypothesizing about the edit — cheap, conclusive, and rules out (or confirms) your change as the cause before you spend probes on it.
3. Build a red-capable repro loop: command/check/artifact, exact symptom, expected vs observed, determinism or reproduction rate.
4. Minimize until remaining elements are load-bearing.
5. Generate ranked falsifiable hypotheses.
6. Probe one variable at a time; prefer targeted evidence over broad logging. Tag every debug log with a unique prefix (e.g. `[DEBUG-a4f2]`) so cleanup is one grep.
7. State root cause with confidence and evidence.
8. Hand off minimal fix plan to `dev-*` with regression-test seam.
9. Once the fix lands: re-run the original repro loop (must go green), grep and remove tagged debug instrumentation, and state the confirmed root cause in the commit/PR message.

## Reassessment Rules

- If first fix fails, stop and reassess the hypothesis before trying another fix.
- If three fixes fail, stop patching and map shared state, hidden coupling, environment, and assumptions.
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
