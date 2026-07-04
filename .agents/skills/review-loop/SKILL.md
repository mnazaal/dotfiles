---
name: review-loop
description: Use when the user has reviewed an AI-generated diff and left inline `>>> agent:` markers requesting changes or asking why; resolve each marker in place, leave every edit unstaged so the staging area stays the human-audited ledger.
---

# Skill: Review Loop

Turns human review of a diff into applied changes. The user reviews side-by-side
(e.g. `vdiff-magit`), stages the hunks they have audited, and drops `>>> agent:`
markers where they want changes or an explanation. This skill consumes those
markers.

## The Staging Ledger

The git staging area is the record of "reviewed with my own eyes". It is the
user's, not yours.

- Never run `git add`, `git stage`, `git commit`, or `git reset` here. Leave all
  edits in the working tree, unstaged.
- Before editing, note the staged files: `git diff --cached --name-only`. If a
  marker asks you to change content that is already staged, do **not** silently
  rewrite it — resolving it would un-audit an approved hunk. Flag it and let the
  user unstage first.
- Staged hunks are frozen. Your edits touch unstaged regions only.

## Marker Convention

A marker is a single comment line in the file's native comment syntax:

```
# >>> agent: use the existing retry helper instead of this loop
// >>> agent: why is this cast needed?
```

- One marker anchors to the code immediately around it — that is the diff anchor.
- A marker requesting a **change** → apply it, then delete the marker line.
- A marker phrased as a **question** → answer in chat, leave the marker in place
  for the user to delete. Do not edit code for a pure question.
- If intent is ambiguous, ask; do not guess and edit.

## Phase 1: Collect

1. Find markers: `Grep` for `>>> agent:` across the working tree.
2. Note staged files (`git diff --cached --name-only`) to protect the ledger.
3. If no markers exist, say so and stop — nothing to do.

## Phase 2: Resolve

Handle each marker in file order:

1. Read the surrounding hunk for context.
2. Change request → make the minimal edit that satisfies it, delete the marker.
3. Question → answer concisely in chat, cite `file:line`, leave the marker.
4. Ledger conflict (marker inside a staged hunk) → report it, skip the edit.

Keep every change unstaged.

## Phase 3: Hand-off

1. Report per anchor: what changed (or the answer), and any skipped/ambiguous
   markers.
2. Remind the user to re-review the new unstaged delta and stage what they
   accept — only the delta needs re-auditing; already-staged hunks are untouched.
3. Commit is not this skill's job. Route to `dev-git` (staged-only), gated by
   `dev-verification` evidence for non-trivial changes. A staged-only commit
   after a full audit carries the `Human-audited: yes` trailer (`dev-git`) —
   the ledger's durable record; `git-audit-coverage` reports line coverage
   from it via blame.

## Boundary

- This skill applies review feedback and answers review questions.
- It does not stage, commit, or decide integration — `dev-git` owns that.
- It does not prove the change is correct — `dev-verification` owns that.

## Related Skills

- `dev-verification` for evidence before any completion claim.
- `dev-git` to commit the staged-only result and choose integration path.
- `decide-review` for the review gate before integration.
- `dev-audit` when auditing a standing codebase to coverage — the macro
  campaign that drives many such diffs — not resolving markers on one diff.
