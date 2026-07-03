---
name: decide-review
description: Use for code review decisions: receiving review feedback, requesting review, classify comments, critical/important/minor/invalid/deferred, evidence-backed responses, review gates before merge.
---

# Skill: Decide Review

## Rules

- Verify technical claims before accepting them.
- Do not perform agreement; respond with decision and evidence.
- Separate correctness/security from style/preference.

## Workflow

### Receive Review

1. List feedback items.
2. Classify: critical, important, minor, invalid, deferred.
3. Verify questionable claims against code/tests/docs.
4. Decide action per item; ask before implementing if unclear or scope-changing.
5. Push back with evidence when feedback is technically wrong, stale, unsafe, or violates current requirements.
6. Hand implementation to `dev-*` or debugging to `debug-*`.

### Request Review

Trigger points: major feature checkpoints, before merge/PR, after complex bug fixes, or when a fresh technical perspective is useful.

1. Define review scope: diff/files, requirement, risk areas, known gaps.
2. Provide reviewer only the work product and acceptance criteria, not session history.
3. Ask for findings classified as critical, important, minor, invalid, or deferred.
4. Apply this skill's receive-review flow to results.
5. Use `dev-verification` before claiming review fixes pass.

## Red Flags

- Accepting feedback because it sounds authoritative.
- Performing agreement instead of checking code reality.
- Skipping review because the change is "simple" but risky.
- Ignoring critical/important findings without explicit technical rationale.

## Related Skills

- `dev-verification` before claiming review fixes pass.
- `dev-git` when review gates merge/PR.
