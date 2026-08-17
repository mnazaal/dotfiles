---
name: dev-verification
description: Use before claiming work is complete, fixed, passing, ready, merged, reviewed, or verified; evidence-before-completion gate, fresh checks, command output, status proof.
---

# Skill: Dev Verification

## Rules

- Follow AGENTS.md “Shell Output Capture”: long/background verification writes full output and exit status to files; add unbuffered output only when the command supports it and you need live log checks. Never rely on `cmd | tail`/`head` evidence.
- Evidence before claims.
- No completion, fixed, passing, ready, reviewed, or verified claim without fresh verification evidence.
- Run the verification that proves the claim or state why blocked.
- Run a slow check in the background once and let it report when it finishes; never hand-roll a `sleep`/`pgrep` poll loop to watch a command you already backgrounded — it outlives the job and leaks.
- To tell whether a backgrounded job is actually working vs. stalled, compare accumulated CPU time (`ps -o time`) to wall-clock elapsed — near-zero CPU growth over minutes means blocked/hung, not busy.
- Read full relevant output, including exit status and failures.
- Do not extrapolate from partial checks.
- Do not trust delegated-agent reports without checking produced artifacts/diffs.
- A failure trace ending in worker/plugin teardown (e.g. xdist `OSError: cannot send`, `PluggyTeardownRaisedWarning`) with no `FAILED` line is harness/infra flake, not a regression — rerun once plain before treating it as real.
- Resource-shaped parallel-test failures (worker death, process/thread creation failures, near-zero worker CPU growth while memory is exhausted) are infrastructure evidence first, not code evidence; rerun with lower/no parallelism before debugging application code.
- Prevent oversubscription before it freezes an interactive machine: before a heavy local check (JAX/numpy/pytorch tests, probes, smoke runs), cap library thread pools (`OMP_NUM_THREADS`/`OPENBLAS_NUM_THREADS`/`MKL_NUM_THREADS=1`, XLA single-thread) and never run two core-saturating jobs concurrently — library-threads × cores × stacked process pools can pin the whole workstation, not just slow the check.
- To certify a numerical result is *correct* (not merely stable), check it against an independently-derived reference that shares no code path with the implementation (textbook formula in numpy/scipy, autodiff vs. analytic, a second library, brute-force enumeration) — and write that reference before reading the code's own tests, so their assertions don't anchor it. A test that asserts the code's own output proves stability, not correctness. A port may claim only “matches the reference implementation” from recorded replay/parity evidence; independent numerical correctness needs a separate oracle.
- A passing correctness check certifies only the input regime it exercised. When the cheap gate runs at a benign scale (tiny values, short sequences, small deltas) but deployment runs orders of magnitude larger, add a check in the deployment-magnitude regime — sign/scale/overflow bugs hide where the gate never looks.
- A repair is done when a review has looked at the repair, not when the code changes. The pass that writes a fix may only mark the finding repaired and pending review; clearing it needs a read by a pass that did not write it (a fresh subagent, or a later session reading it cold). A fix can introduce a worse defect than the one it removed, and the agent holding the fix in context is the worst-placed reader to notice — the same asymmetry that makes `session-handoff`'s cold-read check a separate step.
- Re-review the code, not the finding list. Verifying only the items a reviewer raised certifies those lines and nothing else; a repair's new defect is by construction absent from the list that prompted it.
- Verify a review claim before accepting it, and push back with evidence when feedback is stale, unsafe, or contradicts current requirements. Agreement is not a response.

## Gate

1. Identify the exact claim.
2. Identify command/check/artifact that proves it.
3. Run or inspect it fresh.
4. Report actual result with evidence.
5. Only then make the claim.

## Evidence Table

| Claim | Requires |
|-------|----------|
| tests pass | focused/full test command output with zero failures |
| lint clean | configured lint command output with zero errors |
| types clean | configured type checker (`ty check`, or project's own) output with zero errors — required alongside tests/lint for non-trivial Python changes |
| build works | configured build command exits zero |
| bug fixed | original symptom or regression test now passes |
| requirement met | checklist against requirement text, not only tests |
| computation numerically correct | independent from-scratch reference (no shared code path) agrees to expected precision — not a golden snapshot of the code's own output |
| port matches reference implementation | recorded replay/parity evidence against the reference implementation, with scope and tolerances stated |
| experiment pipeline works | e2e smoke run through the real entry point on tiny synthetic data — loss drops, metrics/artifacts logged (`dev-ml-infra`); unit-green alone is insufficient |
| agent completed | inspect changed files/artifacts, then verify independently |
| flag/option behaves as documented | resolved default read from source or a runtime probe — `--help` and docstrings go stale, and a default decides whether config is needed at all |
| rename/repath complete | the OLD name has zero hits across every relevant file type (`.py` **and** `.md`/`.rst`/`.ipynb`/config), searched whitespace-tolerantly — a line-anchored `grep`/`sed` sweep reports false-clean on references wrapped across lines (docstrings, RST `:class:`/`:mod:` links) |
| review finding resolved | the repair re-read by a pass that did not write it; the pass that wrote the fix may only mark it pending review |
| A is faster than B | both timings from one interleaved run (separate runs drift), best-of-N, and every timed run asserted to have produced its expected artifact — a run that failed early is the fastest run. A difference smaller than the spread between repeats of the *same* input is noise, not a result |

## Anti-Patterns

- "Should pass".
- "Probably", "seems", or satisfaction before evidence.
- Previous run as current evidence.
- Linter passing used as build/test evidence.
- Code changed used as bug-fixed evidence.
- Partial checks presented as full proof.
- Golden-snapshot or self-referential test (reuses the code's own helpers/output) treated as correctness evidence — it guards regressions, it does not prove correctness.
- Re-deriving a property of an existing run from *assumed* or *default* inputs and trusting the result — the run's own recorded config (`params.json`, resolved config, manifest) is the source of truth; recomputing with a guessed upstream parameter launders an assumption into apparent evidence.
- Background watcher loops left running after the watched command exits (`pgrep -f "x"` self-matches its own argv and never terminates).
- Recommending configuration from a truncated `--help`/docs read — dump the full option surface and read all of it before advising which flags to set.
- Closing a finding you repaired in the same pass, or treating the reviewer's finding list as the scope of the re-review.
- Timing a command without asserting it did the work — a broken run is the fastest run, so a surprisingly fast variant is a failure until proven otherwise.
- Treating an impossible measurement (removing work made it *slower*) as a result rather than as a readout of your noise floor.

## Related Skills

- `dev-tdd` for red-green behavior.
- `debug-root-cause` if verification fails unexpectedly.
- `dev-worktree` for PATH/venv gotchas when the verified command runs inside a git worktree.
