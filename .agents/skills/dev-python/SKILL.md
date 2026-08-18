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
- For greenfield ML research repo layout, follow `dev-ml-infra`'s Research Project Layout.
- When promoting/moving code that already has many existing importers (e.g. test-helper logic being promoted to a real package location), a thin re-export shim (`from new.location import (names)` + matching `__all__`) is allowed only as a temporary migration tactic in the same change or a user-approved follow-up. Otherwise update importers and delete the old surface (`dev-ponytail`).
- Hand-editing `pyproject.toml` dependencies does NOT update the lockfile (only `uv add`/`uv remove` do) — run `uv lock` and commit the refreshed lock in the *same* change. A stale committed lock isn't merely out of date: the next `uv sync` on any other machine (CI, a teammate, the cluster) re-resolves it into a *different* lock, so environments silently diverge.
- A **library** does not cap its dependencies. An upper bound propagates to every downstream user and collides with other libraries' caps; when an incompatibility appears, fix it at your own boundary (lazy import, narrower surface) rather than freezing the user's stack — and check which package actually broke first, since capping the one that merely *changed* aims at the wrong dependency. Applications may pin; libraries constrain.
- Keep heavy or optional third-party imports inside the function that uses them. A module-scope import puts that dependency and its whole transitive tree on the import path of the entire package, so an upstream break anywhere in that tree makes `import yourpackage` fail for every user — including those who never touch the feature. Verify with `sys.modules` before and after the top-level import.

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
uv lock                 # re-resolve after a MANUAL pyproject edit (uv add/remove do this for you)
uv sync                 # restore from lockfile

# Tests — use the project-configured runner; otherwise prefer the worktree-local executable or `uv run pytest` when uv owns the environment
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
- Treat slow or worker-crashing parallel test runs as verification/resource questions first (`dev-verification`); rerun with lower/no parallelism before debugging code.

## Related Skills

- `dev-jax` for framework-specific code.
- `dev-ml-infra` for experiment config/tracking/progress conventions.
- `dev-tdd` for test-first behavior.
- `dev-verification` before completion claims.
- `dev-worktree` when the project lives in a git worktree with its own `.venv`.
