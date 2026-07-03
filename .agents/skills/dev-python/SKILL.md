---
name: dev-python
description: Use for Python code/projects: pyproject.toml, virtual environments, dependencies, packaging, tests, linting, scripts, notebooks, experiment layout, importable library code, project conventions.
---

# Skill: Dev Python

## Rules

- Read project files first: `pyproject.toml`, lockfiles, requirements, test config, CI, nox/tox.
- Prefer project-local environments and tools; avoid hidden global state.
- Respect existing package manager/build backend instead of converting projects casually.
- Keep importable library code separate from scripts/notebooks.
- Keep side effects out of core logic when a seam is possible.
- Put runnable experiments under existing project experiment conventions.
- Use `pytest` for Python tests unless the project dictates otherwise.
- Prefer existing project tools. In greenfield projects, default without asking to: `uv` (env/deps), `pytest`, `ruff`, `ty` (type check), and `dev-ml-infra`'s experiment stack (hydra-zen configs, MLflow behind a tracker seam). Ask only when deviating from these defaults.
- Type public surfaces fully: complete signatures on public functions/methods. `Any`, untyped `dict` payloads, and bare `# type: ignore` are code smells — reach for a precise type, `TypedDict`/dataclass, or protocol first; if `Any` is truly unavoidable, say why at the use site.
- Annotate array code with `jaxtyping` shape/dtype types (`Float[Array, "batch dim"]`); shapes in types beat shapes in comments or docstrings.
- Research code is a library others benchmark against and extend: every method *and baseline* implements the same small, deep interface; a method coupled to the harness is a structural smell. The entry-point/extension contract lives in `dev-ml-infra`.
- When promoting/moving code that already has many existing importers (e.g. test-helper logic being promoted to a real package location), turn the origin module into a thin re-export shim (`from new.location import (names)` + matching `__all__`) rather than updating every call site. Same correctness, far smaller diff, zero risk of missing an importer.

## Workflow

1. Identify existing Python conventions.
2. Define package/module/test seam.
3. Add or update behavior through public interfaces.
4. Run focused `pytest` verification unless directed to another test runner.
5. Run broader verification before completion.

## Commands

```bash
# Environment and deps (uv)
uv venv && uv pip install -e ".[dev]"
uv add <package>        # adds to pyproject.toml + lockfile
uv sync                 # restore from lockfile

# Tests — pytest only; never python -m pytest or uv run pytest
pytest                          # full suite
pytest tests/test_foo.py -x     # focused, stop on first failure
pytest -k "test_name" -v
pytest -n0 ...                  # override an addopts-hardcoded `-n` to disable xdist for one run

# Lint / type check — use whatever the project has configured
ruff check .
ty check                 # greenfield default; fall back to pyright/mypy where ty hits gaps
```

## Anti-Patterns

- Global dependency installs without user/project intent.
- Ad hoc `sys.path` hacks when packaging has a proper seam.
- Mixing notebooks/scripts with core library behavior.
- Inventing a new tracker/config system when project already has one.
- `-p no:xdist` when `addopts` hardcodes `-n <workers>` — conflicts and errors; use `-n0` to override instead.

## Related Skills

- `dev-jax` and `dev-pytorch` for framework-specific code.
- `dev-ml-infra` for experiment config/tracking/progress conventions.
- `dev-tdd` for test-first behavior.
- `dev-verification` before completion claims.
- `dev-worktree` when the project lives in a git worktree with its own `.venv`.
