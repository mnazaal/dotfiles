---
description: Review a branch with code-reviewer children, every changed file accounted for
argument-hint: "[base] [what the change is for]"
---
Review the committed changes on this branch.

1. Arguments: `$@`. If the first one (`$1`) names a commit (`git rev-parse --verify --quiet "$1^{commit}"` succeeds), it is the base and the rest (`${@:2}`) say what the change is for. Otherwise the base is `main` and all the arguments say what the change is for. The range is `<base>...HEAD`. Uncommitted changes are not part of it, so say so if `git status --short` lists any.
2. List the changed files with `git diff --name-only <base>...HEAD`. Deleted files stay in the list, since a deletion can remove a guard.
3. If no arguments say what the change is for, take it from this conversation, or else from `git log --format=%s <base>..HEAD`. If that still gives nothing, leave `request` out of the workflow args: the workflow rejects an empty string.
4. With 15 files or fewer, run one `code-reviewer` subagent on the whole range, passing the range, the file list, and what the change is for. Compare its coverage list with the step-2 list; any file it did not list is left over.
5. With more than 15, run the workflow script at `~/.pi/agent/workflows/code-review.js` (expand `~` to an absolute path) with `args: { range, request, files }`. `files` is ONE string with one path per line, not an array: workflow args cap arrays at 64 items. Run the workflow on at most 200 files at a time; for more, split the list and run it once per part. The JSON-encoded `args` must stay under 16 KiB, so keep `files` under 12,000 bytes and `request` under 1,000 characters. One run starts at most 64 children; files past that come back under `missing`. Use `async: true`. If a launch fails, report its error and stop. Do not fall back to a single reviewer. The files under `missing`, and under `failedBatches`, are left over.
6. Send the leftover files once more, in batches of at most 8: one `code-reviewer` for 8 or fewer, the workflow for more. Do this once.
7. Report the findings in the `code-review` skill's Output format, most severe first, then the coverage count. Every file still unreviewed, and every coverage entry marked `skipped` with its reason, goes on its own line under "Not reviewed". If `droppedFindings` is above 0, say so: a reviewer reported on a path outside its batch. Do not fix anything.
