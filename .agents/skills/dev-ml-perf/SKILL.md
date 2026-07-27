---
name: dev-ml-perf
description: Use when an ML job is slow or runs out of memory: profiling before optimizing, deciding whether the bottleneck is GPU compute, data input, or recompilation, GPU memory accounting, OOM triage, and measuring step time correctly on asynchronous devices. Framework-specific fixes route to dev-jax and dev-pytorch.
---

# Skill: Dev ML Perf

## Iron Law

Measure before changing. Name the bottleneck with evidence, change one thing,
re-measure. An untimed "optimization" is a guess, and on a shared cluster it
spends someone else's hours too.

## Timing Correctly

GPU work is asynchronous — the launch returns before the compute finishes.

- Synchronize before reading the clock (`torch.cuda.synchronize()`,
  `jax.block_until_ready(x)`). Without it you are timing dispatch, not compute,
  and every change will look free.
- Discard the first steps from any average: they include compilation,
  autotuning, and allocator warm-up.
- Report steps/sec or samples/sec, not total wall time. Total time hides whether
  a change improved throughput or merely ran fewer steps.

## Diagnostic Ladder

1. **Is the GPU busy?** Watch utilization across a window, not one instant
   (`nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv -l 1`).
   Sustained low utilization means the GPU is waiting on something.
2. **Input-bound?** Replace the loader with a single cached batch, repeated. If
   throughput jumps, the bottleneck is the input pipeline, not the model — fix it
   there (`dev-ml-data`: cache keying, worker count, preprocessing placement).
3. **Recompiling?** A slow first step is expected; every step slow means
   retracing. In JAX, changing shapes or Python-side constants retriggers
   tracing; under `torch.compile`, look for graph breaks. Count compilations and
   log shapes before concluding a kernel is slow.
4. **Actually compute-bound?** Only now profile kernels and consider precision,
   fusion, or a better algorithm (`dev-jax` / `dev-pytorch`).

## Memory and OOM

Account before shrinking. Device memory is parameters + gradients + optimizer
state + activations.

- Adam keeps two extra copies per parameter; activations scale with batch size
  and depth. Whichever term dominates decides which lever actually works.
- Triage order: (1) retained references — a loss tensor appended to a list holds
  its whole graph alive, so store `.item()`/`float()`; (2) activation
  checkpointing; (3) precision; (4) batch size LAST, because changing it changes
  the experiment.
- If a smaller batch is unavoidable, gradient accumulation preserves the
  effective batch. Otherwise record it as a changed config, not a free win
  (`research-run` will not compare across it).

## Anti-Patterns

- Optimizing without a measurement that names the bottleneck.
- Timing GPU work without synchronizing.
- Averaging the compile step into the reported step time.
- Reducing batch size as the first OOM response, silently changing the experiment.
- Reaching for AMP, `torch.compile`, or donation while the job is input-bound.
- Profiling on a login node instead of inside an allocation (`dev-hpc`).

## Boundary

- Owns naming the bottleneck with evidence, and memory accounting. It stops there.
- Once the bottleneck is named, the fix is `dev-jax` / `dev-pytorch` — do not tune here.
- Slow because the input pipeline is wrong is `dev-ml-data`.
- Slow on a cluster because of allocation, partition, or launcher shape is `dev-hpc`.
- A performance change that alters batch size or any other config has changed the experiment; `research-run` decides whether results still compare.
- Fast but wrong is not a perf problem — `debug-ml-research`.

## Related Skills

- `dev-jax` / `dev-pytorch` for framework-specific fixes once the bottleneck is named.
- `dev-ml-data` when the bottleneck is the input pipeline.
- `dev-hpc` for running the profile inside a job, and for GPU/driver checks.
- `research-run` when a performance fix changes the run's configuration.
- `debug-root-cause` for a performance regression with an unknown cause.
