---
name: dev-jax
description: Use for JAX code: jax, jax.numpy, jit, vmap, scan, grad, pytrees, explicit PRNG keys/state, optax, blackjax, distrax, gpjax, flax, equinox, Bayesian/probabilistic/causal ML.
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
- Enable x64 at module level (`jax.config.update("jax_enable_x64", True)`) for scientific/causal algorithms that need it; do it before any array creation.
- pytest-xdist runs one process per worker, each independently JIT-compiling; a full parallel suite can multiply memory/CPU far past a single-process run. Scope JAX tests to changed files by default; if workers die without test failures, rerun with lower/no parallelism before debugging code (`dev-verification`).
- `jax.tree_util.tree_flatten`/`tree_leaves` treat each array as one leaf, not per-element, and visit dict keys in sorted order, not insertion order. Don't assume element-wise or insertion-order leaf indexing when writing tooling that reports "the Nth leaf" (e.g. a NaN-locating diagnostic) — verify against an actual flattened tree.

## Workflow

1. Define params, state, data, and key interface.
2. Implement eager pure function first.
3. Add vectorization/scan/grad.
4. Verify shapes, dtypes, pytrees, and gradients.
5. JIT stable heavy paths.
6. Keep side effects in thin outer layers.

## Idioms

```python
# PRNG — split at every call site; never reuse a key
key, subkey = jax.random.split(key)
x = jax.random.normal(subkey, shape)

# vmap — vectorise over leading axis; broadcast constants with None
batched = jax.vmap(fn, in_axes=(0, None))(xs, constant)

# scan — sequential with carry (prefer over Python loops inside jit)
def step(carry, x):
    return new_carry, output
final_carry, outputs = jax.lax.scan(step, init, xs)

# jitted train step — JIT the entire grad+update, not just grad
@jax.jit
def train_step(params, opt_state, batch):
    loss, grads = jax.value_and_grad(loss_fn)(params, batch)
    updates, opt_state = optimizer.update(grads, opt_state)
    return optax.apply_updates(params, updates), opt_state, loss

# in-place update — .at[].set(), never direct assignment
arr = arr.at[i].set(val)
```

## Anti-Patterns

- Passing the same key variable into two sequential `jax.random.*`/sampler calls within one function — split one subkey per independent random decision up front (`k1, k2, ..., kN = jax.random.split(key, N)`), even when the decisions are small and sequential, not just across function boundaries.
- Printing inside jit except `jax.debug.print`.
- Passing loop-varying scalars (penalty weights, dual variables, temperatures) via closure into a jitted function — they bake into the XLA graph and force recompilation on every change. Pass them as explicit positional args instead.
- Un-jitted optimizer step functions called from a Python training loop — calling bare `jax.grad + optax.update` in a plain `for` retraces and dispatches on every iteration (100× slower). Always `@jax.jit` the `(grad + update)` step; iterate with a plain Python `for` over the jitted call.
- `jnp.where(mask, f(x), fallback)` still evaluates `f(x)` on the masked-out branch and adds its gradient — if `f` is singular there (`log`, `logcdf`, `sqrt`, `1/x` at `0` or `±inf`) the backward pass is NaN even though the forward value is correct. Substitute a safe finite input first (`x_safe = jnp.where(mask, x, 1.0)`), apply `f` to `x_safe`, then `where` to select. Verify with `jax.grad`, not just a forward eval — the value looks fine either way.
- Long/background command evidence belongs in `dev-verification`; for Python/JAX scripts that must be monitored live, use unbuffered output so redirected logs advance incrementally.
- Module-level experiment drivers with no `if __name__ == "__main__":` guard — they re-run the whole experiment on import. Guard them so probes stay importable by other scripts.
- Wrapping `jax.jit` around a function the caller already compiles — a NumPyro/BlackJAX model the sampler traces wholesale, or a helper called once — adds compile overhead with nothing to amortize. Jit stable, repeatedly-called heavy paths; leave already-traced and single-call code bare.

## Related Skills

- `dev-python` for Python project/tooling conventions.
- `debug-ml-research` for silent experiment failures.
- `dev-verification` before completion claims.
