---
name: dev-worktree
description: Use when working inside a git worktree (multiple checkouts of one repo, e.g. `.claude/worktrees/*`): running tests/tools, per-worktree virtualenvs, PATH resolution across sibling checkouts.
---

# Skill: Dev Worktree

## Rules

- A worktree's own `.venv` does not change shell PATH: bare `pytest`/`python` invocations can silently resolve to a sibling checkout's venv, importing a different package install.
- Before trusting a bare tool invocation, check `which <tool>` or invoke the worktree-local path explicitly (`.venv/bin/pytest`, `.venv/bin/python`).
- Treat a `ModuleNotFoundError`, or an `ImportError: cannot import name X from Y` for a symbol you just added/changed, as a PATH/venv-resolution symptom first, not necessarily a real missing-dependency or circular-import bug.
- An isolated worktree `.venv` resolves dependencies independently: a wave of same-subsystem failures often means unpinned-dependency drift (a newer release broke an API, e.g. `AttributeError: ... has no attribute X`), and a `ModuleNotFoundError` there can be a genuinely missing optional dep — check installed versions against the project's pins, and re-run with your changes stashed, before suspecting your code.

## Related Skills

- `dev-python` for environment/dependency conventions.
- `dev-verification` before completion claims.
- `dev-git` for attributing a readiness-check failure to your change vs pre-existing before merging.
