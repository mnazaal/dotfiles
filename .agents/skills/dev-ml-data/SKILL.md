---
name: dev-ml-data
description: Use when building or changing data handling in an ML project: dataset provenance and versioning, generating train/val/test splits, grouped and temporal splitting, preprocessing and normalization statistics, feature/label alignment, preprocessing caches, dataloader determinism, and synthetic data generators with known ground truth.
---

# Skill: Dev ML Data

## Purpose

Build data handling that cannot silently corrupt an experiment.
`debug-ml-research` diagnoses these failures after a run; this skill is the
constructive side. Scope is the correctness spine only — the places where a
mistake produces plausible numbers instead of an error.

## Rules

### Provenance

- Record source, retrieval date, version or checksum, and license for every raw
  dataset before first use. `data/raw/` is append-only and never edited in
  place.
- Derived data must be reproducible from raw plus code. If it is not
  reproducible, it is raw — move it.

### Splits

- Splits come from a seeded, versioned function and are persisted as explicit ID
  lists. Do not regenerate them per run from a live shuffle: a split that moves
  between runs invalidates every cross-run comparison (`research-run` treats
  split compatibility as a precondition).
- Split on the grouping unit, not the row — patient, subject, session, document,
  molecule, site, time window. A random row split leaks whenever several rows
  share a unit, and the leak shows up as unusually good validation numbers, not
  as an error.
- Time-ordered data splits temporally. A random split lets the model see the
  future.

### Preprocessing statistics

- Any quantity fit from data — normalization mean/std, vocabulary, PCA basis,
  class weights, imputation values, feature selection, discretization bins — is
  fit on train only, persisted, and applied unchanged to val and test.
  Fit-then-split is the most common silent leak in ML code.
- Persist those statistics next to the checkpoint. Recomputing them at eval time
  against a different sample silently changes the model's input distribution.

### Caching

- The cache key covers the preprocessing code version, not just the input path.
  A cache keyed on filename serves stale tensors after a transform changes, and
  nothing raises.
- Cached artifacts record the config that produced them, so a mismatch is
  detectable rather than assumed absent.

### Determinism and tripwires

- Seed the loader, not just the model: shuffle order, augmentation, and
  per-worker RNG. Workers that inherit one seed replay identical augmentation
  streams (`dev-pytorch` / `dev-jax` for the framework-specific form).
- Assert dataset size, label distribution, and dtype at the loader boundary.
  These are cheap and catch a truncated file, a mis-parsed column, or a silently
  empty filter.

## Workflow

1. Record provenance for each raw source before reading it.
2. Identify the grouping unit, and whether ordering matters; pick the split kind
   from that, not from convenience.
3. Generate splits once with a recorded seed; persist the ID lists.
4. Fit preprocessing statistics on train; persist them with the model.
5. Build the cache with a key covering inputs and preprocessing code version.
6. Add size, dtype, and label-distribution assertions at the loader boundary.
7. For a new method, write the synthetic generator before touching real data.

## Synthetic Generators

- The generator returns the data *and* the true parameters or latents. One that
  returns only data cannot support a recovery test.
- Expose the knob that moves the problem from identifiable to non-identifiable,
  so a recovery test can be shown to detect failure rather than merely pass
  (`debug-ml-research` covers reading the result).
- Keep generators in the package, not a notebook or sibling script: a worker
  unpickles them in another process and cwd (`dev-hpc`).

## Anti-Patterns

- Fitting a scaler, vocabulary, or PCA basis before splitting.
- Random row splits on grouped or time-ordered data.
- Regenerating splits each run instead of persisting them.
- Cache keyed on filename or path alone.
- Seeding the model but not the loader or augmentation.
- Editing `data/raw/` in place.
- A synthetic generator that returns data without the ground truth it was drawn
  from.

## Boundary

- Owns the data correctness spine: provenance, splits, preprocessing statistics, caches, loader determinism, synthetic generators.
- Diagnosing a data bug that already reached a run is `debug-ml-research`; this skill is the constructive side.
- Where `data/` and `results/` sit, and how runs are launched, is `dev-ml-infra`.
- Loader and PRNG mechanics in a specific framework are `dev-pytorch` / `dev-jax`.
- Input-pipeline throughput is `dev-ml-perf` — correctness here, speed there.

## Related Skills

- `debug-ml-research` when a data bug has already reached a run.
- `dev-ml-infra` for where `data/` and `results/` sit and how runs are launched.
- `research-run` for split and data compatibility before comparing runs.
- `dev-pytorch` / `dev-jax` for loader and PRNG specifics.
- `dev-hpc` for package reachability when generators run on a worker.
