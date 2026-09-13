---
name: dev-worktree
description: "Use when working inside a git worktree (one repo checked out at several paths at once): running tests/tools, per-worktree virtualenvs, PATH resolution across sibling checkouts."
---

# Skill: Dev Worktree

## Location

Create a worktree under the scratch directory the environment already provides —
`"$TMPDIR/wt-<topic>"` — and never inside the project tree or beside the
repository it came from.

Two reasons, both about what happens later. Scratch paths are exempt from the
recursive-removal guard, so cleaning one up is a plain command rather than a
permission prompt; a sibling directory under the projects tree is not exempt and
every removal there interrupts. And a worktree beside its own repository is
findable by tooling that expected one checkout: a bare `pytest` or `python` can
resolve into it, which is the failure the Rules below are about.

Scratch is cleared between sessions, so treat the directory as disposable and
the branch as the artifact — commit before you stop. A cleared scratch area
leaves the worktree registered, which `git worktree prune` clears; Cleanup below
has the order.

## Rules

- A worktree's own `.venv` does not change shell PATH: bare `pytest`/`python` invocations can silently resolve to a sibling checkout's venv, importing a different package install.
- Before trusting a bare tool invocation, check `which <tool>` or invoke the worktree-local path explicitly (`.venv/bin/pytest`, `.venv/bin/python`).
- Treat a `ModuleNotFoundError`, or an `ImportError: cannot import name X from Y` for a symbol you just added/changed, as a PATH/venv-resolution symptom first, not necessarily a real missing-dependency or circular-import bug.
- An isolated worktree `.venv` resolves dependencies independently: a wave of same-subsystem failures often means unpinned-dependency drift (a newer release broke an API, e.g. `AttributeError: ... has no attribute X`), and a `ModuleNotFoundError` there can be a genuinely missing optional dep — check installed versions against the project's pins, and re-run with your changes stashed, before suspecting your code.

## Cleanup

A worktree outlives the reason it was made, and its branch outlives the
worktree. Both strand quietly.

- **Prune before deleting.** `git branch -d` refuses a branch that ANY worktree
  has checked out, including one whose directory no longer exists — a scratch
  worktree leaves its registration behind when the scratch area is cleared, so
  git still believes the branch is checked out. `git worktree prune` drops those
  registrations; it removes no work and is safe to run at any time.
- **Step off the branch first.** The other reason the same command refuses is
  the ordinary one: you are standing on it. Switch to the base branch, then
  delete.
- **Remove a live worktree explicitly** rather than deleting its directory:
  `git worktree remove <path>`, adding `--force` only when you accept losing
  uncommitted changes there.
- **Deleting the worktree does not delete the branch**, which is the property
  worth relying on — the commits survive a cleared scratch area. Retire the
  branch as a separate, deliberate step once it is merged.

Order that always works: prune, switch off the branch, remove the worktree,
then delete the branch.

## Related Skills

- `dev-python` for environment/dependency conventions.
- `dev-verification` before completion claims.
- `dev-git` for attributing a readiness-check failure to your change vs pre-existing before merging.
