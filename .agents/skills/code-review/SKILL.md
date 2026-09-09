---
name: code-review
description: "Use when reviewing a diff, a commit, a branch, or freshly written code — especially code an agent wrote — before it is committed, merged, or built on. Reading agent-written ML code for defects: deleted numerical guards, invented constants, wrong axis or convention, tests that mirror the implementation."
---

# Skill: Code Review

Reading a diff catches roughly half of what goes wrong in agent-written research
code. The dominant empirical failure mode is code that passes its tests and is
still wrong, and a diff cannot show it. So this skill does two things: it reads
the diff for what reading can catch, and for the rest it names the one probe
that would settle the question.

## Rules

- Read the change against the REQUEST, never against its own docstring or
  comments. An agent generates a faithful docstring from the request and
  slightly wrong code beneath it; a reviewer checking code-against-docstring
  confirms the wrong thing.
- A diff shows deletions, not omissions. Ask what the code never does — never
  split the key, never masked, never mutilated the graph, never added the
  Jacobian — because none of that has a line to look at. When the change is a
  NEW file the whole file is the diff, and omissions are maximally invisible.
- Report at most three findings. Each names its severity and the single check
  that would settle it. A finding you cannot pair with a settling check is a
  hunch — drop it.
- Every finding is advisory. Nothing here blocks a commit.
- Scale depth to blast radius, not to diff size: a two-line change to a loss, a
  mask, or a metric outranks a hundred lines of plotting.

## Read the diff for

Ordered by yield on agent-written code.

- **Deleted numerical guards.** Jitter, `+1e-8`, `stop_gradient`, `dtype=`,
  validity masks, `where` clamps. Refactor passes strip these because they read
  as clutter. Diff specifically for removals, not just additions.
- **New numeric literals.** Every `1e-6`, `n_samples=100`, `tol`, threshold,
  temperature is a silent modelling decision. Ask where each came from.
- **Scope over-reach.** What does this change do that nobody asked for? Agents
  implement more than requested more often than less.
- **Convention drift across call sites.** Adjacency orientation, logits vs
  probs, mask polarity changed at one site and not its partners. Each edit is
  locally correct; the pair is wrong.
- **Tests that mirror the implementation.** Does the test assert against an
  independent oracle, or against the code's own output? An agent writes the
  test from the same misreading of the spec, so green certifies consistency,
  not correctness.
- **Imports and API symbols that may not exist.** Package and attribute
  hallucination is the one class where a mechanical check beats reading.
- **Swallowed failure.** `except: pass`, `.get(key, default)` on a required
  config, a loader that falls back to synthetic data when a file is missing.
- **Reimplemented primitives.** Hand-rolled `logsumexp`, softmax, KL, SHD,
  Cholesky solve — the textbook formula without the library's guards.

## Prescribe a probe for

These cannot be settled by reading. Name the applicable one; do not claim the
code is correct without it.

- Metric or split provenance suspect → label-shuffle control; the metric must
  collapse to chance.
- Axis, broadcast, or reduction suspect → shape probe with every dimension a
  distinct prime.
- Seeding or pairing suspect → same seed twice (bit-identical), two seeds
  (different).
- Eval path suspect → a tripwire arm that must fail (transposed adjacency,
  random graph, zero-width interval) through the identical path.
- `stop_gradient`, a missing term, or custom autograd → finite-difference the
  gradient. The forward value cannot catch it.
- Objective semantics → evaluate at a closed-form point and compare to hand
  arithmetic.
- `vmap`/`scan` axes or carry → compare against a three-item Python-loop
  reference.
- A captured constant or retracing → `fn._cache_size() == 1` after several
  same-shape calls.
- float64 intended → assert a `.dtype` on the compute path, not that the flag
  line exists.
- A config override → read the run's own recorded resolved config.

## Do not flag

The exclusion list is what keeps the output short enough to stay read.

- Anything the configured linter or type checker already reports. Run
  `ruff check` and `ty check` and cite them; do not imitate them.
- Style, naming, formatting, import order, docstring wording.
- Defense-in-depth on code that is already guarded.
- Unchanged code surrounding the diff.
- Theoretical risk with no traced path to a wrong result.
- Library or dependency swaps, unless a hallucinated symbol is the finding.
- Performance, unless the change is on a measured hot path.

## Output

```
<severity: critical | warning | note>  <file:line>
<what is wrong, one sentence>
Settles it: <the single command, probe, or file to read>
```

Three findings maximum. If nothing meets the bar, say the diff looks sound and
name what you checked — an all-nits review is evidence the change is fine, not
a reason to promote a nit.

## Boundary

- Owns: reading a change for defects, and naming the probe that settles what
  reading cannot.
- Does not own completion claims — `dev-verification` holds that gate, and its
  rule that a repair is cleared only by a pass that did not write it.
- Does not own experiment validity — splits, metrics, leakage and design belong
  to the `eval-review` role.
- Does not own diagnosis. A confirmed-wrong result routes to
  `debug-ml-research`; a crash or failing test routes to `debug-root-cause`.

## Related Skills

- `dev-verification` for the evidence standard and the separate-reader rule.
- `debug-ml-research` for the silent-failure probes named above.
- `dev-jax` for PRNG discipline, retracing, and `jnp.where` gradient traps.
- `dev-tdd` for what earns a characterization test.
- `dev-ponytail` when the finding is that the code should be smaller.
- `agent-orchestration` when more than one reviewer reads the same artifact.
