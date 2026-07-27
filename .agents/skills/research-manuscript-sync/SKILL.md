---
name: research-manuscript-sync
description: Use when syncing a manuscript directory to a hosted LaTeX git bridge (Overleaf): git subtree push/pull, rejected force-push or non-fast-forward, re-seeding a pre-existing subdir, bridge branch conventions, and verifying that no parent-repo paths leak across the sync boundary.
---

# Skill: Research Manuscript Sync

## Purpose

Move a `manuscript/` subdir of a monorepo to and from a hosted LaTeX git bridge
without fighting the bridge or leaking the parent repo. Provider-specific
troubleshooting — verify current provider behavior and repository state before
any destructive recovery path.

Depends on one rule owned by `research-manuscript-workflow`: a synced manuscript
directory IS the artifact, so it must compile standalone, generators live
outside it, and generated figures/tables are committed. Load that skill for the
boundary itself; this one covers moving it across.

## Bridge Constraints

Plan for a locked-down remote:

- Default branch is usually `main`, not `master`.
- `--force` and pushing new branches are typically FORBIDDEN.
- History must be linear and built on the bridge's own initial commit.

## Re-seeding a Pre-existing Subdir

`git subtree push` from a subdir that already existed never fast-forwards — its
split shares no commit with the bridge's first commit, and force is rejected.
The fix is a one-time `subtree add` re-seed:

1. Drop the prefix: `git rm -r <dir> && git commit`, THEN `rm -rf <dir>`.
   `git rm` leaves untracked and ignored files (e.g. `build/`) behind, so the
   directory survives on disk and `subtree add` refuses with "prefix already
   exists".
2. `git subtree add --prefix=<dir> <remote> main`.
3. Restore your content, commit, then push.

Any seed or re-seed branch is one-time throwaway scaffolding — delete it once
the re-seed lands. A long-lived one is pure bookkeeping.

## Recurring Sync

- `git subtree pull` / `git subtree push`, wrapped as `make <host>-pull` /
  `make <host>-push`.
- **Pull before push.**
- **Commit before push** — subtree only sends committed state.
- Sync from the integration branch (usually `main`). The sync boundary is the
  `--prefix` **subdir**, NOT a branch, so keep no dedicated manuscript or host
  branch.
- Committed generated artifacts ride along automatically; never force-add them.

## Scope Check

Only the `--prefix`'d subdir crosses to the host. After a push, inspect the
actual remote tree and confirm ZERO parent-repo paths (`src/`, tests,
lockfiles):

```bash
git ls-tree <host>/main
```

Passing `--prefix=<dir>` on every push and pull is the boundary. The sole leak
vector is a bare `git push <host>` of the whole repo, which the bridge shape
rejects anyway. Verify the tree; do not assume it.

## Boundary

- This skill owns the bridge-specific re-seed and sync procedure.
- `dev-git-rescue` owns general history rewriting and recovery — reflog, bisect,
  revert vs reset, scripted rewrites. Route there when the problem is the local
  history rather than the bridge.

## Related Skills

- `research-manuscript-workflow` for the synced-boundary rule this depends on.
- `dev-git-rescue` for general history surgery.
- `dev-git` for the commit-before-push discipline and integration path.
