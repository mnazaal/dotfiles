---
name: dev-git
description: Use when committing work or choosing integration path: stage correctly, write an informative commit message, add honest AI attribution trailers, then decide merge/PR/park/abandon.
---

# Skill: Dev Git

## Rules

- If anything looks like a private email/user's personal directories/password/secret/API token etc, stop and notify the user immediately.
- Stage specific files by name; never `git add -A` or `git add .` without reviewing what would be included.
- AI attribution trailers must be accurate — use `Assisted-by:` (not `Co-Authored-By:`) for AI tools, and only when AI substantially contributed (not tab-completion or trivial fixes). This deliberately overrides Claude Code's built-in commit-heredoc template, which defaults to `Co-Authored-By:`; don't let the more prominent built-in win — `Co-Authored-By: <AI> <noreply@…>` misattributes copyright and can link a real GitHub account via the email.
- `Human-audited: yes` trailer: add only when the user explicitly confirms they reviewed every staged hunk (e.g. after a `review-loop` pass — staged = audited); never self-certify. A commit mixing audited and unaudited hunks gets no trailer — split it. Line-level audit coverage is computed from blame by `git-audit-coverage`.
- Run `dev-verification` evidence (tests, lint) before committing if the change is non-trivial.
- Do not amend a pushed commit without explicit user confirmation.
- Verify status before integration decisions.
- Inspect diff/scope and recent commits before recommending merge/PR.
- When a readiness check surfaces failures, attribute each to your change vs pre-existing before deciding merge: cross-check against your changed files, then stash and re-run a representative failure. Stash-and-rerun clears only your diff, not cross-venv dependency drift — for that use `dev-worktree`. Pre-existing env/dependency failures don't block your merge; never report a red suite as green.
- Do not discard work or force-push without explicit confirmation.
- If a commit/push/rebase is rejected with `GIT PRE-COMMIT/PRE-PUSH/REFERENCE TRANSACTION HOOK ERROR: <prefix> agent must/may only ... <prefix>/* (or worktree-<prefix>*) branches` — you're running under an agent branch-prefix guard (`AGENT_BRANCH_PREFIX`, set by the `renv <agent>.sh` env files; see `~/.config/git/hooks/`). Check `git branch --show-current`: it must be `<prefix>/*`, or `worktree-<prefix>*` if in a `-w`-created worktree. Fix by switching to a correctly named branch — never unset the guard or add `--no-verify` to work around it without explicit user confirmation.

## Phase 1: Commit

1. `git diff HEAD` — review what changed; confirm scope matches intent.
2. Check `git config user.name` — the human must be the commit **author**; agent environments may default to a bot identity.
3. Stage specific files by name. If splitting work into multiple commits, run
   `git status` before each commit — the index holds *everything* staged so far
   (e.g. leftover from an earlier `git rm`), not just the most recent `git add`;
   `git restore --staged <path>` to drop anything that shouldn't ride along.
4. Write the commit message:
   - Imperative subject ≤ 50 chars.
   - Conventional Commits prefix if the project uses them (`feat:`, `fix:`, `refactor:`, `chore:`, etc.).
   - Body (optional): *why*, not a file list.
   - Trailer block: one `Assisted-by: <tool-name> (<model-id>)` line per AI tool that substantially contributed. Use `Assisted-by:`, never `Co-Authored-By:`. Add `Human-audited: yes` only under the rule above.
5. Commit via heredoc to preserve formatting and trailers:
   ```bash
   git commit -m "$(cat <<'EOF'
   feat: short imperative subject

   Why this change exists (optional body).

   Assisted-by: <tool-name> (<model-id>)
   EOF
   )"
   ```
6. `git show --stat HEAD` — confirm the commit looks right.

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
- `dev-audit` for a codebase-wide human-verification campaign that drives `Human-audited:` coverage across many commits.
