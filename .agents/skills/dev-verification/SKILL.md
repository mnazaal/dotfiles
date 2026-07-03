---
name: dev-verification
description: Use before claiming work is complete, fixed, passing, ready, merged, reviewed, or verified; evidence-before-completion gate, fresh checks, command output, status proof.
---

# Skill: Dev Verification

## Rules

- Evidence before claims.
- No completion, fixed, passing, ready, reviewed, or verified claim without fresh verification evidence.
- Run the verification that proves the claim or state why blocked.
- Run a slow check in the background once and let it report when it finishes; never hand-roll a `sleep`/`pgrep` poll loop to watch a command you already backgrounded — it outlives the job and leaks.
- Do not pipe a backgrounded command through `tail`/`head`; output buffers until exit, looks stuck, tempts a redundant watcher, and the reported exit code is the pipe's last stage (e.g. `tail`), not the real command — treat it as untrustworthy. Send full output to a file and read that.
- Read full relevant output, including exit status and failures.
- Do not extrapolate from partial checks.
- Do not trust delegated-agent reports without checking produced artifacts/diffs.
- A failure trace ending in worker/plugin teardown (e.g. xdist `OSError: cannot send`, `PluggyTeardownRaisedWarning`) with no `FAILED` line is harness/infra flake, not a regression — rerun once plain before treating it as real.

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
| experiment pipeline works | e2e smoke run through the real entry point on tiny synthetic data — loss drops, metrics/artifacts logged (`dev-ml-infra`); unit-green alone is insufficient |
| agent completed | inspect changed files/artifacts, then verify independently |

## Anti-Patterns

- "Should pass".
- "Probably", "seems", or satisfaction before evidence.
- Previous run as current evidence.
- Linter passing used as build/test evidence.
- Code changed used as bug-fixed evidence.
- Partial checks presented as full proof.
- Background watcher loops left running after the watched command exits (`pgrep -f "x"` self-matches its own argv and never terminates).

## Related Skills

- `dev-tdd` for red-green behavior.
- `debug-root-cause` if verification fails unexpectedly.
- `dev-worktree` for PATH/venv gotchas when the verified command runs inside a git worktree.
