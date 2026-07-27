---
name: dev-ml-infra
description: Use for ML experiment infrastructure: hydra-zen configs, config management, experiment tracking, MLflow, wandb, tracker seams, progress bars, tqdm, long-run log output, training-pipeline smoke tests.
---

# Skill: Dev ML Infra

## Research Project Layout

For greenfield ML research repos, default to one inspectable, reproducible
layout:

```text
project-name/
  pyproject.toml
  uv.lock
  README.md
  PLAN.md
  LOG.md

  src/
    project_name/
      __init__.py
      data/
      methods/
      models/
      experiments/
      eval/
      tracking/
      config/
      run.py

  tests/
    test_smoke.py

  scripts/
    reproduce_main.sh

  data/
    raw/
    processed/
    README.md

  results/
    README.md
    runs/
    mlruns/
    outputs/
    multirun/
    artifacts/

  notes/
```

- `README.md`, `PLAN.md`, `LOG.md`, and `notes/` are part of the standard
  research layout; follow `context-project-docs` for their roles and write
  policy.
- `src/project_name/` holds importable library code. Experiment harness code
  depends on methods; methods do not depend on the harness.
- `results/` is the only generated-output root. Put MLflow state, Hydra
  outputs, sweeps, checkpoints, figures, tables, logs, and artifacts under it.
- `results/runs/<run_id>/` is the canonical human-readable per-run record:
  resolved config, git commit, seed, metrics, logs, and artifacts.
- Make each run's output path unique by its FULL sweep key — every varied
  parameter — not a partial key plus a wall-clock timestamp. A second-resolution
  timestamp collides for runs launched in the same second, and an omitted sweep
  param collides across a sweep; either way concurrently-launched runs silently
  overwrite on a shared filesystem and the loss surfaces only as *missing*
  results, never an error. Keep a timestamp only to disambiguate genuine re-runs
  of the identical config. (`dev-hpc` covers the sibling hydra `job.num` case.)
- Track only layout/provenance docs inside generated-data/output directories
  (`data/README.md`, `results/README.md`); gitignore generated contents.
- One command path should run every method/baseline through the same interface:
  `python -m project_name.run method=X data=Y seed=0`.

Minimum run surface:

```bash
uv sync
pytest
python -m project_name.run method=my_method data=synthetic seed=0
./scripts/reproduce_main.sh
```

## Config (hydra-zen)

- Configs are code: `builds()`/`just()`/`make_config()` live next to the components they configure; no YAML config trees at all — launchers included. YAML isn't IDE-navigable (no jump-to-definition or type-checking on config params), which is the point of config-as-code.
- `instantiate` at the entry point only; library code never imports hydra-zen.
- Every config field is typed and has a default a smoke run can use.
- CLI entry: expose a script's `main(**params)` (defaults = the run defaults) via `zen(main).hydra_main(...)` over `builds(main, populate_full_signature=True)`; params become `key=value` overrides, lists as `xs=[a,b,c]`. Wrap this in one shared helper so each script's `__main__` stays a one-liner.
- Migrating argparse → hydra-zen: turn each `add_argument` into a typed kwarg on `main`; comma-string sweep args (`--gammas 0.5,0.9`) become native list params.
- A `str` config field whose valid values look boolean (`mode: str = "true"`, allowing `{'true','false','both'}`) is a trap: Hydra parses the CLI literal `mode=true` as a bool, OmegaConf coerces it into the str field as `"True"` (capital T), and a raw `mode in {'true',…}` check then rejects the documented spelling — at runtime, on the cluster. Normalize (`str(x).strip().lower()`) before validating, rather than quote-escaping the CLI.

## Tracking

- Experiment code depends on a small `Tracker` protocol (`start_run`, `log_params`, `log_metrics`, `log_artifact`, `end_run`) — one module.
- MLflow is the default backend; `import mlflow` appears in exactly one adapter module, so swapping to wandb is one file.
- Log config, git commit, and seed at run start; metrics at a fixed cadence; artifacts by path.

## Extension Contract

- One config-driven entry point runs any method or baseline (`python -m proj.run method=X data=Y`); adding a method = implement the shared method interface (`dev-python`) + one config entry — true for your own next baseline and for external users alike.
- Identical metric logging for every method, so external comparisons are direct; no separate plugin machinery — externals extend through the same seams you use (`dev-ponytail`).

## Progress Output

- Interactive TTY: tqdm/rich progress bar.
- Captured output (agent-run, nohup, SLURM, redirect): no `\r` bars — they explode into thousands of junk lines. Emit periodic structured lines instead: `step 400/10000 loss=0.2311 lr=3e-4 eta=12m`, every N steps or T seconds.
- One code path, switched on `sys.stderr.isatty()`; structured lines are also the greppable record for analyzing long runs.

## Smoke Run

- Every experiment repo has a standing e2e smoke test: the full pipeline through the real entry point on tiny synthetic data with a known answer (~50 steps) — asserts loss decreases, metrics/artifacts land in the tracker, checkpoint reloads.
- The smoke run, not unit-test green, is the completion evidence for pipeline changes (`dev-verification`).
- No backward compatibility: change configs and interfaces freely and fix call sites (`dev-ponytail`).

## Anti-Patterns

- YAML sprawl or stringly-typed configs resolved at runtime.
- A hand-written `sbatch`/bash launcher or per-experiment `scripts/*.sh` instead of a registered hydra experiment run via `python -m …run … hydra/launcher=… --multirun` (`dev-hpc`).
- `import mlflow`/`import wandb` scattered through experiment code.
- Progress bars in captured logs.
- A smoke test that mocks the tracker or bypasses the real entry point.
- Adding a second sweep axis under one run/tag without checking the aggregation step groups by it — an aggregator keyed only on the first axis (e.g. strategy) silently pools across the new axis, and if it pairs on a shared key (seed) the repeated keys collide (last-write-wins). One swept value per tag, or fix the grouping first.

## Boundary

- Owns the experiment scaffolding: repo layout, hydra-zen config, tracker seam, progress output, the smoke run, the one entry point.
- What goes inside `data/` — provenance, splits, preprocessing statistics — is `dev-ml-data`.
- The model and numerics behind the entry point are `dev-jax` / `dev-pytorch`.
- Getting these configs onto a cluster, and everything about submission, is `dev-hpc`.
- Interpreting what the runs produced is `research-run`; this skill only ensures they are comparable and reproducible.

## Related Skills

- `dev-python` for project/env conventions.
- `dev-ml-data` for what goes in `data/`: provenance, splits, preprocessing statistics, caches.
- `dev-jax` / `dev-pytorch` for the model code itself.
- `dev-tdd` and `dev-verification` for the e2e-evidence discipline.
- `research-run` for interpreting the runs this infra produces.
- `debug-ml-research` when a run is plausible but wrong.
- `dev-hpc` for getting these configs/entry points running on a SLURM cluster.
