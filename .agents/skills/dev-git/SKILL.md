---
name: dev-git
description: Use when committing work or choosing integration path: stage correctly, write an informative commit message, add honest AI attribution trailers, then decide merge/PR/park/abandon.
---

# Skill: Dev Git

## Rules

- If anything looks like a private email/user's personal directories/password/secret/API token etc, stop and notify the user immediately.
- Stage specific files by name; never `git add -A` or `git add .` without reviewing what would be included.
- AI attribution trailers must be accurate — use `Assisted-by:` (not `Co-Authored-By:`) for AI tools, and only when AI substantially contributed (not tab-completion or trivial fixes). This deliberately overrides Claude Code's built-in commit-heredoc template, which defaults to `Co-Authored-By:`; don't let the more prominent built-in win — `Co-Authored-By: <AI> <noreply@…>` misattributes copyright and can link a real GitHub account via the email.
- Staging is the user's record of what they have actually read. Stage what you are told to stage; never stage on the user's behalf to make a commit look complete.
- Run `dev-verification` evidence (tests, lint) before committing if the change is non-trivial. Evidence must reflect the *committed* state: inspect the staged diff and ensure no relevant unstaged or untracked changes are required for the check to pass.
- Do not amend a pushed commit without explicit user confirmation.
- Verify status before integration decisions.
- Inspect diff/scope and recent commits before recommending merge/PR.
- When a readiness check surfaces failures, attribute each to your change vs pre-existing before deciding merge: cross-check against your changed files, then isolate your diff and re-run a representative failure. Do not automatically stash/reset/checkout across staged hunks or unrelated user changes; use `dev-worktree` for cross-venv dependency drift. Pre-existing env/dependency failures don't block your merge; never report a red suite as green.
- Do not discard work or force-push without explicit confirmation.
- Treat integration writes as gated proactively, not reactively: a repo may confine the agent to its own feature branches (via hooks, sandboxing, or absent remote auth). Don't `git push`, or update a shared/protected branch (`main`/`master` or the integration base), yourself — present the exact command for the user to run instead of offering to execute it. Rebasing a feature branch *onto* the base is fine (it writes only the feature ref), but `git checkout <feature>` first, then `git rebase <base>`; rebasing while standing on the base branch can trip a pre-rebase guard.
- If a commit/push/rebase is rejected with `GIT PRE-COMMIT/PRE-PUSH/REFERENCE TRANSACTION HOOK ERROR: <prefix> agent must/may only ... <prefix>/* (or worktree-<prefix>*) branches` — you're running under an agent branch-prefix guard (`AGENT_BRANCH_PREFIX`, set by the `renv <agent>.sh` env files; see `~/.config/git/hooks/`). Check `git branch --show-current`: it must be `<prefix>/*`, or `worktree-<prefix>*` if in a `-w`-created worktree. Fix by creating/switching to a fresh `<prefix>/<topic>` branch (Phase 1 "Branch first") — never unset the guard or add `--no-verify` to work around it without explicit user confirmation.

## Phase 1: Commit

**Branch first for new independent work.** Prefer a fresh `<prefix>/<topic>`
branch created from the integration base (usually `main`) for a new unit of
work. If the user already put you on a scoped active branch, inspect ancestry and
scope before preserving it; don't pile unrelated work onto a reused or
already-merged branch. Under an agent branch-prefix guard this also avoids the
rejected-commit round-trip.

1. `git diff HEAD` — review what changed; confirm scope matches intent.
2. Check `git config user.name` — the human must be the commit **author**; agent environments may default to a bot identity.
3. Stage specific files by name. If splitting work into multiple commits, run
   `git status` before each commit — the index holds *everything* staged so far
   (e.g. leftover from an earlier `git rm`), not just the most recent `git add`;
   `git restore --staged <path>` to drop anything that shouldn't ride along.
   When one *file* carries two threads and interactive staging (`git add -p`) is
   unavailable, don't squash them by default: snapshot the final versions outside
   the repo, remove the second thread's content, commit the first, then restore
   the snapshot for the second. **Verify before staging** — grep the intermediate
   state for the other thread's distinctive terms and confirm zero matches. A
   half-peeled document commits content whose rationale lives in a commit that
   does not exist yet, which is worse than not splitting at all.
4. Write the commit message:
   - Imperative subject ≤ 50 chars.
   - Conventional Commits prefix if the project uses them (`feat:`, `fix:`, `refactor:`, `chore:`, etc.).
   - Body (optional): *why*, not a file list.
   - Trailer block: one `Assisted-by: <tool-name> (<model-id>)` line per AI tool that substantially contributed. Use `Assisted-by:`, never `Co-Authored-By:`.
5. Commit via heredoc to preserve formatting and trailers:
   ```bash
   git commit -m "$(cat <<'EOF'
   feat: short imperative subject

   Why this change exists (optional body).

   Assisted-by: <tool-name> (<model-id>)
   EOF
   )"
   ```
6. `git show --stat HEAD` — confirm the commit contains *every* file you intended, not just that it looks plausible. A failed pathspec in a multi-path `git add` (e.g. a path already `git rm`'d) aborts the whole add, silently leaving the rest unstaged — a mixed `rm`+`add` refactor can commit a half-migration (broken imports) this way.

## Phase 2: Integration

1. Require `dev-verification` evidence for any completion/readiness claim.
2. Summarize scope and risk. For a merge, dry-run it first: `git merge-tree $(git merge-base <target> <branch>) <target> <branch>` — inspect for conflict markers before recommending merge, without touching the working tree.
3. If review was requested, pass through `decide-review` before proceeding.
4. Present options: PR, merge, continue, park, cleanup, abandon.
5. Execute only chosen safe path.
6. Report final state and next action.

## Boundary

- This skill commits work and chooses integration path.
- It does not prove work is complete; `dev-verification` owns proof.
- History rewriting and recovery (rebase scripting, reflog rescue, revert vs reset, bisect) live in `dev-git-rescue`.

## Related Skills

- `dev-verification` before committing non-trivial changes or making completion claims.
- `dev-git-rescue` for history rewriting and recovery.
- `decide-review` for review gate before integration.
- `dev-worktree` when a suspected pre-existing failure needs cross-venv verification, not just a stash.
- `dev-tdd` for what earns a characterization test before you touch it.
