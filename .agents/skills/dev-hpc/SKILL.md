---
name: dev-hpc
description: Use for running experiments on an HPC/SLURM cluster (e.g. Triton): remote code sync, submitit/hydra launchers, sbatch, GPU wheel selection, per-cluster resource configs, one-way results rsync, GPU driver/CUDA checks, cluster reproducibility.
---

# Skill: Dev HPC

## Purpose

Get a project's experiments onto a SLURM cluster and results back, reproducibly, driven from a laptop.

## Code + Env Sync

- Sync code to the cluster over git (push to a remote/bare repo the cluster pulls). rsync is for *results only*, one-way.
- Pin cross-machine deps as git deps at an explicit commit (`tool.uv.sources.<pkg> = { git = "ssh://git@github.com/owner/repo.git", rev = "<sha>" }`), never an editable local path — a path dep can't resolve identically on the cluster. Use the `ssh://git@host/owner/repo.git` scheme; uv rejects the `git@host:owner/repo` shorthand ("relative URL without a base").
- `.venv` is per-machine: `uv sync` on the cluster, never rsync it. Cluster-only extras (GPU wheels) install there.
- Extras installed via `uv sync --extra X` stick in `.venv`, but a later bare `uv run ...` (without repeating `--extra X`) auto-resyncs the env to the base dependency set first, silently pruning the extra back out. Either pass `--extra` on every `uv run`, or activate the venv and call `python` directly — that skips the resync.

## GPU Wheels

- Pick the CUDA extra by the node's *driver* version, not any installed toolkit: jax `cuda12` needs driver >=525, `cuda13` needs >=580 — verify current thresholds at docs.jax.dev, don't trust memory.
- Driver version isn't the whole story — CUDA major versions also drop support for older GPU *architectures* independent of the driver floor, e.g. cuda13 requires SM>=7.5 and silently excludes Volta/V100 (SM 7.0) even on a driver that clears 580. Check `nvidia-smi --query-gpu=compute_cap` against the target release's minimum SM, not just its driver requirement, especially when the partition spans multiple GPU generations.
- The login node has no GPU; `nvidia-smi` only works inside a job: `srun --gres=gpu:1 --time=00:05:00 --pty nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv`.
- Keep the GPU extra optional so the laptop stays CPU-only.

## Submission (hydra + submitit)

- Launch via `hydra-submitit-launcher`; each cluster/partition is a launcher config (`conf/hydra/launcher/<name>.yaml`) holding partition/gres/mem/timeout. This is the one place a small config file beats builds()-in-Python (`dev-ml-infra`).
- `--multirun` is REQUIRED for the launcher to engage — even for a single job. Without it Hydra runs in-process locally.
- submitit shells out to `sbatch` itself, so submission runs *from* the cluster; it can't launch from the laptop.
- Pin each run's output dir under the rsync'd results dir, keyed on a known config name — `${hydra.job.name}` resolves to hydra-zen's wrapper module, not your script.
- Any code the task function references must be reachable from the installed package, not a sibling script — `from other_script import fn` between two `experiments/*.py` files works locally (the script's own dir lands on `sys.path`) but submitit's remote worker unpickles the job in a different process/cwd, so it can't find `other_script` and dies with `ModuleNotFoundError`. Move shared logic into the package proper.
- The local driver process blocks the shell until the submitted job(s) finish (it polls submitit for results) — background it (`&` + `disown`, `nohup ... &`, or tmux) rather than tying up the terminal. Once it's printed the submitted job ID(s), Ctrl-C only kills the local polling loop, not the Slurm job — submission already reached the scheduler.
- That driver process also imports the task function's full module (jax included) on the *login node* before submitting, even for a GPU-launcher override — expect a harmless CUDA-init warning there (no GPU on the login node). Don't force `JAX_PLATFORMS=cpu` to silence it on a GPU job: `sbatch` inherits the submitting shell's environment by default, so that would also force the actual compute-node job onto CPU.

## Results

- Pull one-way, cluster→laptop, `rsync -avz` (never push back) — safe to run mid-job.
- Gitignore generated output (`experiments/results/`, hydra's `outputs/`, `multirun/`): synced, not versioned.
- Result dirs accumulate from failed/OOM-killed/timed-out jobs too. Filter what you pull by `sacct -j <job_id> --allocations` (ground truth for job outcome — catches failures a Python-side try/except would miss) keyed off each run's `.submitit/<job_id>/`, rather than a hand-rolled success marker. Only within `sacct`'s retention window (~30 days typically).

## Sandbox Handoff

- Operations needing SSH auth to a remote (push/clone of a private repo, `uv sync` resolving a git dep, first host-key accept) fail in a sandboxed agent session. Hand the exact command to the user (`!` prefix); don't retry it yourself.

## Related Skills

- `dev-ml-infra` for the hydra-zen config layer and experiment entry point.
- `dev-python` for uv/env/extras conventions.
- `dev-git` for the commit + private-repo push discipline.
- `dev-jax` for GPU/x64 specifics of the code being run.
