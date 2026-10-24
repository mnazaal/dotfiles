---
name: dev-ml-infra
description: "Use for ML experiment infrastructure and data handling: train/val/test splits, grouped and temporal splitting, preprocessing statistics and caches, dataloader determinism, data leakage prevention, hydra-zen configs, config management, experiment tracking, MLflow, wandb, tracker seams, progress bars, tqdm, long-run log output, training-pipeline smoke tests."
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
- Place each output by what reads it, when the run writes it. A record
  (metrics, resolved config, logs, summaries) is read on the laptop and is
  pulled. Resume state (training checkpoints, caches a requeued job reloads)
  is read only by the cluster job: write it under the run's `.ckpt/`. A large
  final artifact (weights) is pulled on demand: write a sidecar beside it
  (`weights.sha256`) so a readout checks the sidecar, not the artifact.
- Track `results/.rsync-filter` (gitignore `results/*` plus
  `!results/.rsync-filter`; a bare `results/` cannot be re-included). It lists
  `.ckpt/` and every other kind the laptop never reads; `rsync -F` applies it
  on the cluster (`dev-hpc`).
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
  `data/README.md` names each dataset's source, version or hash, download date,
  and licence, including whether it permits redistribution and whether it holds
  personal data — written when the data arrives, not at submission.
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
- Create the MLflow experiment with an explicit `artifact_location` under `results/`: the artifact store defaults to `./mlruns` at the cwd even when the tracking DB lives under `results/`.
- Log config, git commit, seed, dirty-tree flag (with `git diff` as an artifact when dirty), the `uv.lock` hash, jax/jaxlib/CUDA versions, device type, and the dataset identity (version or content hash) at run start; metrics at a fixed cadence; artifacts by path.

## Output Size

A run's output is sized when its writer is written, not when the laptop fills.

- Arrays go in `np.savez_compressed`. JSON/JSONL rows hold scalars; a trajectory or per-step array goes in the run's compressed array file. A float written as JSON text costs ~19 bytes, against 4 stored as float32.
- Store each field at the precision its readout needs, not the precision it was computed in: float64 numerics usually store as float32. Keep float64 for a field a readout subtracts or exponentiates at full precision, and say which.
- Decide before launch whether any readout needs raw samples. If none does, store the summaries the readouts compute. If one does, the samples are a large final artifact (Research Project Layout).
- A finished sweep gets a collect step on the cluster that merges its per-task files into one table for the tag (`results/<tag>/table.parquet`); readouts read the table. Per-task files stay (see Smoke Run on shared writes), but 100k files of 3 KB cost twice their bytes in filesystem blocks and pull slowly.
- The task writes `status.json` in its run dir from a `try/finally` around the whole body: `ok`, or the exception and traceback. That is the task-body outcome `dev-hpc` otherwise reads from hydra's `*_result.pkl` (~80 KB of pickled config per run), which then goes in `.rsync-filter`.

## Extension Contract

- One config-driven entry point runs any method or baseline (`python -m proj.run method=X data=Y`); adding a method = implement the shared method interface (`dev-python`) + one config entry — true for your own next baseline and for external users alike.
- Identical metric logging for every method, so external comparisons are direct; no separate plugin machinery — externals extend through the same seams you use (`dev-ponytail`).

## Progress Output

- Interactive TTY: tqdm/rich progress bar.
- Captured output (agent-run, nohup, SLURM, redirect): no `\r` bars — they explode into thousands of junk lines. Emit periodic structured lines instead: `step 400/10000 loss=0.2311 lr=3e-4 eta=12m`, every N steps or T seconds.
- One code path, switched on `sys.stderr.isatty()`; structured lines are also the greppable record for analyzing long runs.

## Smoke Run

- Every experiment repo has a standing e2e smoke test: the full pipeline through the real entry point on tiny synthetic data with a known answer (~50 steps) — asserts loss decreases, metrics/artifacts land in the tracker, checkpoint reloads, and the run's output dir minus `.ckpt/` stays under a byte budget scaled from the expected per-run size. The budget is what makes Output Size hold: a format that bloats fails a test before it reaches the cluster.
- The smoke run, not unit-test green, is the completion evidence for pipeline changes (`dev-verification`).
- No backward compatibility: change configs and interfaces freely and fix call sites (`dev-ponytail`).
- Every run must converge on re-run. Ask what a second launch does, and what a launch after a crash mid-write does. The failure is a truncated cache, checkpoint, or metrics file that still loads: write to a temp path and rename, and validate a cache before adopting it. Resume must reach the same end state as a clean run.
- Before two jobs can write one path, remove the sharing rather than lock it: give each array task its own output file or directory and merge at read time. Two workers writing different fields of one `state.json`, appending to one `results.csv`, or filling one preprocessing cache is still a race — "they won't collide" is not concurrency control.

## Anti-Patterns

- YAML sprawl or stringly-typed configs resolved at runtime.
- A hand-written `sbatch`/bash launcher or per-experiment `scripts/*.sh` for an *experiment or sweep* instead of a registered hydra run via `python -m …run … hydra/launcher=… --multirun` (`dev-hpc`; a recurring single job such as a test gate is the exception).
- `import mlflow`/`import wandb` scattered through experiment code.
- Progress bars in captured logs.
- A smoke test that mocks the tracker or bypasses the real entry point.
- Adding a second sweep axis under one run/tag without checking the aggregation step groups by it — an aggregator keyed only on the first axis (e.g. strategy) silently pools across the new axis, and if it pairs on a shared key (seed) the repeated keys collide (last-write-wins). One swept value per tag, or fix the grouping first.

## Boundary

- Owns the experiment scaffolding: repo layout, hydra-zen config, tracker seam, progress output, the smoke run, the one entry point.
- What goes inside `data/`: fit preprocessing on train only — fit-then-split
  is the most common silent leak; split on the grouping unit, not the row;
  persist seeded splits as ID lists; cache keys cover the preprocessing code
  version; seed loader workers, not just the model.
- The model and numerics behind the entry point are `dev-jax`.
- Getting these configs onto a cluster, and everything about submission, is `dev-hpc`.
- Interpreting what the runs produced is `research-run`; this skill only ensures they are comparable and reproducible.

## Related Skills

- `dev-python` for project/env conventions.
- `dev-jax` for the model code itself.
- `dev-tdd` and `dev-verification` for the e2e-evidence discipline.
- `research-run` for interpreting the runs this infra produces.
- `debug-ml-research` when a run is plausible but wrong.
- `dev-hpc` for getting these configs/entry points running on a SLURM cluster.
