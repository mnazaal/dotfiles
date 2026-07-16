---
name: dev-git-rescue
description: Use for git history rewriting and recovery: interactive rebase, squash/reword/reorder, scripted history rewrites, reflog rescue, lost commits/branches, revert vs reset, dropped stashes, bisect.
---

# Skill: Dev Git Rescue

## History Rewriting

1. Preserve pending work before touching history. Do not automatically stash/reset/checkout across staged hunks or unrelated user changes; inspect `git status`, get confirmation, or work from an isolated branch/worktree.
2. Work on a separate branch, not `main`/`master` directly.
3. Avoid `filter-branch` (deprecated, fragile with stash refs) regardless of approach.
4. For reword/squash/reorder/fixup of existing commits, use `git rebase -i` with
   `GIT_SEQUENCE_EDITOR` set to a non-interactive command (e.g. `cp <todo-file>`) so the
   rebase runs unattended.
5. For fully scripted, mechanical rewrites (bulk author/date fixes across many commits),
   prefer `git commit-tree` + `git update-ref` — it avoids the todo-list format entirely.
6. Apply to `main` with `git reset --hard <branch>` — not `git merge` (unrelated histories
   if `commit-tree` built a fresh chain). Under an agent branch-prefix guard this step
   updates `refs/heads/main` directly and the `reference-transaction` hook will always
   block it — hand this step to the user rather than trying to work around the hook.
7. Before running `git rebase --abort`, check `git log` first — the branch may already be
   at the correct new state, and abort will discard it.

## Recovery

- Bad commit already pushed → `git revert <sha>` (new inverse commit); never rewrite pushed history without explicit user confirmation.
- Bad commit still local → `git reset --soft HEAD~1` to redo message/split; `git reset --hard` only after `git status` confirms nothing unstaged/untracked would be lost.
- Lost commit or branch (bad reset, deleted branch, botched rebase) → `git reflog` to find the sha, then `git branch rescue/<name> <sha>`; reflog retains ~90 days.
- Dropped stash → `git fsck --unreachable | grep commit`, inspect candidates with `git show`.
- Regression of unknown origin → `git bisect` between last known-good and bad, driven by the repro loop from `debug-root-cause`.
- Atomic, focused commits are what make all of the above cheap: one concern per commit means revert and bisect touch exactly the concern in question. Split before committing, not after.

## Related Skills

- `dev-git` for the commit/integration flow and branch-guard rules.
- `debug-root-cause` for the repro loop that drives `git bisect`.
