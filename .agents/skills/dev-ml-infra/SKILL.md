---
name: dev-ml-infra
description: Use for ML experiment infrastructure: hydra-zen configs, config management, experiment tracking, MLflow, wandb, tracker seams, progress bars, tqdm, long-run log output, training-pipeline smoke tests.
---

# Skill: Dev ML Infra

## Config (hydra-zen)

- Configs are code: `builds()`/`just()`/`make_config()` live next to the components they configure; no YAML config trees.
- `instantiate` at the entry point only; library code never imports hydra-zen.
- Every config field is typed and has a default a smoke run can use.

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
- `import mlflow`/`import wandb` scattered through experiment code.
- Progress bars in captured logs.
- A smoke test that mocks the tracker or bypasses the real entry point.

## Related Skills

- `dev-python` for project/env conventions.
- `dev-jax` / `dev-pytorch` for the model code itself.
- `dev-tdd` and `dev-verification` for the e2e-evidence discipline.
- `research-run` for interpreting the runs this infra produces.
- `debug-ml-research` when a run is plausible but wrong.
