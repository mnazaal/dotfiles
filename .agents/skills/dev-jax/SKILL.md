---
name: dev-jax
description: "Use for JAX code, reading PyTorch reference code, and slow or OOMing ML jobs (profiling, step timing, memory): jax, jax.numpy, jit, vmap, scan, grad, pytrees, explicit PRNG keys/state, optax, blackjax, distrax, gpjax, flax, equinox, Bayesian/probabilistic/causal ML."
---

# Skill: Dev JAX

## Rules

- Use `jax.numpy as jnp`; keep NumPy out of transformed compute paths.
- Pass state, parameters, data, and PRNG keys explicitly.
- Split keys at call sites; never hide RNG in globals or objects.
- Prefer pure functions; keep I/O, logging, checkpointing, plotting, and mutation outside compiled cores.
- Use `jax.jit` / `equinox.filter_jit` for stable heavy paths.
- Use `vmap`, `lax.scan`, `grad`, and `value_and_grad` where they make semantics clearer.
- Keep shapes/dtypes stable across jitted calls.
- Use `optax` for optimization, `blackjax` for sampling, `distrax` for distributions, `gpjax` for GPs, and Equinox or project convention for neural nets.
- Enable x64 at module level (`jax.config.update("jax_enable_x64", True)`) for scientific/causal algorithms that need it; do it before any array creation. For Submitit/remote workers, use `dev-hpc`'s launcher environment setup so the flag is set before JAX import on the compute node.
- pytest-xdist runs one process per worker, each independently JIT-compiling; a full parallel suite can multiply memory/CPU far past a single-process run. Scope JAX tests to changed files by default; if workers die without test failures, rerun with lower/no parallelism before debugging code (`dev-verification`).
- `jax.tree_util.tree_flatten`/`tree_leaves` treat each array as one leaf, not per-element, and visit dict keys in sorted order, not insertion order. Don't assume element-wise or insertion-order leaf indexing when writing tooling that reports "the Nth leaf" (e.g. a NaN-locating diagnostic) — verify against an actual flattened tree.
- Write the real invocation before the signature: the concrete shapes and dtypes you will pass, then derive params, state, and key threading from it. Sketch a second, structurally different pytree or axis convention before committing to the first — a different shape, not a renamed field.
- Trace each vmapped or scanned access through the proposed pytree. If the answer is "we reshape at the call site", the structure is wrong. Redesign rather than patch when one workaround recurs: repeated reshape or squeeze at callers, guards multiplying around one branch, or callers having to remember an axis convention the types do not carry.

## Stale Priors

JAX and its libraries move faster than any model's training data, and the
failure is a plausible call that no longer exists or silently means something
else. The installed version is authoritative over recalled patterns: check
`jax.__version__` and the API before writing, and add a row here when a drift
is hit, with the version it was verified against.

| Area | Stale prior | Current (verified jax 0.11.1, 2026-09-15) |
|---|---|---|
| pytrees | `jax.tree_map(f, tree)` | `jax.tree.map(f, tree)` (`jax.tree_map` raises `AttributeError`) |
| PRNG | `jax.random.PRNGKey(0)` (uint32 array) | `jax.random.key(0)` (typed key); `PRNGKey` still works but is legacy |
| numerics | `jnp.trapz` | `jnp.trapezoid` (`trapz` removed) |
| optimizers | `from jax.experimental import optimizers` | removed; use `optax` |
| sharding | `jax.experimental.maps` / `pjit` | `maps` removed; `jax.jit` with `in_shardings`/`out_shardings` and `jax.sharding.NamedSharding` (`pjit` still imports) |

## Workflow

1. Define params, state, data, and key interface.
2. Implement eager pure function first.
3. Add vectorization/scan/grad.
4. Verify shapes, dtypes, pytrees, and gradients.
5. JIT stable heavy paths.
6. Keep side effects in thin outer layers.

## Anti-Patterns

- Passing the same key variable into two sequential `jax.random.*`/sampler calls within one function — split one subkey per independent random decision up front (`k1, k2, ..., kN = jax.random.split(key, N)`), even when the decisions are small and sequential, not just across function boundaries.
- Printing inside jit except `jax.debug.print`.
- Passing loop-varying scalars (penalty weights, dual variables, temperatures) via closure into a jitted function — they bake into the XLA graph and force recompilation on every change. Pass them as explicit positional args instead.
- A jitted function's per-call data whose *shape* grows across a loop (a design-loop history, a growing observed/conditioning set) retraces every step even when passed as a positional arg -- the scalar fix above only helps fixed-shape values, a changing shape still recompiles. Pad it to a fixed MAX shape with a validity mask that zeros the padded slots, so the runtime arg is constant-shape and compiles ONCE. Optional diagnostic: if the callable exposes a cache-size API, `jitted_fn._cache_size() == 1` after several same-shape calls supports the claim; otherwise use tracing/profiling/logging evidence. A cache size > 1 means a shape or a closed-over constant is still varying.
- Un-jitted optimizer step functions called from a Python training loop — calling bare `jax.grad + optax.update` in a plain `for` retraces and dispatches on every iteration (100× slower). Always `@jax.jit` the `(grad + update)` step; iterate with a plain Python `for` over the jitted call.
- `jnp.where(mask, f(x), fallback)` still evaluates `f(x)` on the masked-out branch and adds its gradient — if `f` is singular there (`log`, `logcdf`, `sqrt`, `1/x` at `0` or `±inf`) the backward pass is NaN even though the forward value is correct. Substitute a safe finite input first (`x_safe = jnp.where(mask, x, 1.0)`), apply `f` to `x_safe`, then `where` to select. Verify with `jax.grad`, not just a forward eval — the value looks fine either way.
- Long/background command evidence belongs in `dev-verification`; for Python/JAX scripts that must be monitored live, use unbuffered output so redirected logs advance incrementally.
- Module-level experiment drivers with no `if __name__ == "__main__":` guard — they re-run the whole experiment on import. Guard them so probes stay importable by other scripts.
- Wrapping `jax.jit` around a function the caller already compiles — a NumPyro/BlackJAX model the sampler traces wholesale, or a helper called once — adds compile overhead with nothing to amortize. Jit stable, repeatedly-called heavy paths; leave already-traced and single-call code bare.
- Swapping in a cheaper *algorithm* (coarser grid, mean-field / approximate inference) to speed a hot path before profiling it — the cost is usually loop-invariant **recomputation** (constant arrays rebuilt each step, `jnp` re-dispatched on tiny arrays inside a Python loop, an exact marginal recomputed when its inputs barely moved), not the algorithm. `cProfile` one representative step and hoist the invariants exactly first; that often recovers the speedup with no accuracy loss and shows whether the approximation is needed at all.
- Assuming `vmap`/`jit` over a batch beats an eager per-item loop without timing it. Batching cuts dispatch count, but if the batched dimension's shape varies call-to-call (e.g. a deduplicated particle set of changing size) the program recompiles per shape — compile cost can exceed the dispatch it saved, and eager wins. Time both on the real, shape-varying workload before committing.

## Boundary

- Owns JAX idioms: transformations, PRNG discipline, pytrees, jit/vmap/scan, and the library choices above.
- A slow or OOMing job: name the bottleneck before tuning. Sync before timing
  (`block_until_ready`) and discard compile steps from averages; ask in order —
  is the GPU busy at all → input-bound → retracing → only then optimize
  compute. For OOM, measure what actually allocates before shrinking anything;
  batch size is the last knob, not the first.
- A run that completes and is wrong is `debug-ml-research`, not a transformation bug.
- Matching another implementation's numbers is `dev-jax-port`; this skill assumes JAX is the source of truth, that one assumes it is not. Reference Reading below covers the PyTorch-side reading that precedes a port.

## Reference Reading

- The porting workflow itself (parity testing, replay, layer-by-layer
  verification) is `dev-jax-port`; load it for any port.
- Reading PyTorch reference code: inventory every RNG site (init order,
  DataLoader workers, augmentation); weight layout is convention (`nn.Linear`
  stores W^T) — record layouts at the conversion boundary; harness hooks
  (Lightning) hide the real train step — find it before porting; train/eval
  mode silently changes the numbers you compare against.

## Related Skills

- `dev-python` for Python project/tooling conventions.
- `debug-ml-research` for silent experiment failures.
- `dev-verification` before completion claims.
