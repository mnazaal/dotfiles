---
name: research-manuscript-workflow
description: Use for ML/scientific paper writing and syncing workflows: Overleaf git bridge, git subtree push/pull, rejected force-push or non-fast-forward, re-seeding a pre-existing subdir, LaTeX manuscript directories, paper skeletons, generated figures/tables, citation setup, arXiv/camera-ready preparation, reviewer responses and rebuttals, and agent-safe manuscript collaboration.
---

# Skill: Research Manuscript Workflow

## Purpose

Set the safety and portability boundaries for ML/scientific manuscript work.
For citation or related-work content, load `research-protocol` first. Where a
project's own conventions conflict with anything here, the project wins.

## Core Rule: Human-Owned `.tex`

Treat `.tex` files as human-owned final manuscript source.

Agents may:

- read `.tex` files for context
- compile/check LaTeX if permitted by the host environment
- inspect logs, missing refs, overfull boxes, citation warnings
- propose edits in planning files, comments, or chat
- create/revise planning artifacts outside `.tex`

Agents must not:

- edit `.tex` files directly
- overwrite manuscript source
- auto-format final paper prose
- silently change mathematical claims, notation, theorem statements, or citations

If the user explicitly asks to edit `.tex`, remind them of the guardrail and
offer a patch-like proposal in prose or a non-`.tex` planning file instead.
Only a project-specific policy set by the user may override this, and it must
name the permitted `.tex` paths and review/verification process.

To create a `.tex` skeleton without authoring it, ship a scaffold SCRIPT
(`scaffold.sh`) the human runs — it writes structural stubs only (documentclass,
section headings, commented `\input` hooks; no prose/claims). The agent never
writes `.tex`, even generated ones; the human's execution does. (Some harnesses
enforce this at the permission layer.)

## Core Rule: a synced/portable manuscript directory IS the artifact

When `manuscript/` is git-synced to an external host (Overleaf) or must be
portable (arXiv, coauthor handoff), its contents *become* a standalone project
elsewhere — the directory boundary is an interface, not just a folder. Then:

- **Compile-standalone, zero reachout.** Everything needed to compile the PDF
  lives inside and imports nothing from the parent repo. A file that cannot run
  in the target context — a generator that reads `results/` or imports the
  project package, a Makefile pointing at experiment data — does not belong
  inside the synced boundary.
- **Depend on outputs, not producers.** The generated figures/tables are the
  interface between the reproducibility pipeline and the paper. Keep the
  *producers* (scripts that read results / import the package) in the code layer
  (`scripts/`, `src/`) OUTSIDE the boundary; they write INTO
  `manuscript/figures/generated` and `tables/generated`. Only committed
  artifacts cross the line.
- **Commit the generated artifacts.** They are part of the deliverable and the
  host cannot regenerate them — commit `figures/generated/*` and
  `tables/generated/*`; never gitignore-then-`git add -f`. Confirm no unanchored
  parent rule already ignores them (`git check-ignore <artifact>`) — a repo-wide
  `figures/`/`build/` rule catches `manuscript/figures/` too.
- **Planning stays outside.** The claims/evidence ledger and scaffold/bootstrap
  scripts are not publishable artifacts — keep them in the project's planning
  area (`notes/`) and tooling (`scripts/`), referenced from the manuscript, not
  inside the synced boundary.

The test: could a coauthor download this directory, or arXiv unpack it, and have
it just work?

## Syncing to a hosted git bridge (Overleaf)

When the synced directory is a monorepo subdir pushed to a hosted LaTeX git
bridge, the bridge is locked down — linear history, no `--force`, no new
branches — and a pre-existing subdir needs a one-time re-seed before `subtree
push` will ever fast-forward. The subsections below own that procedure, the
recurring pull/push rules, and the post-push scope check that confirms no
parent-repo paths crossed.

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

## Project Layout Convention

For research projects with code, experiments, notes, and results, prefer a
`manuscript/` directory at the project root:

```text
project/
  docs/
  results/
  scripts/
  src/
  tests/

  manuscript/
    main.tex
    sections/
      00_abstract.tex
      01_intro.tex
      02_background.tex
      03_method.tex
      04_experiments.tex
      05_related_work.tex
      06_discussion.tex
      07_limitations.tex
      08_conclusion.tex
    figures/
      source/         # generators live here ONLY if the manuscript is not externally synced
      generated/      # committed artifacts (the interface)
    tables/
      generated/      # committed artifacts
    macros.tex
    notation.tex
    latexmkrc
    Makefile
```

`manuscript/` is the publication-facing layer. It should consume outputs from
code, experiments, notes, and bibliography tooling, not replace them. When it is
externally synced or must be portable, the Core Rule above governs what may live
here.

Do not put the full paper under `docs/` unless the project already uses `docs/`
as its publication area. `docs/` should usually remain for technical/internal
documentation and related documents.

Do not split the manuscript into a separate repository unless collaboration,
publisher requirements, or artifact submission constraints require it.

The directory has one purpose: produce the paper artifact. Keep generated files
clearly separated from human-authored ones.

## Claims and Evidence Ledger

The ledger is the reserved `notes/claims.md` (`context-project-docs` owns the
name; Markdown — it is a diff-heavy status/pointer file, an exception to the
HTML-notes convention). Keep it in the planning area, not inside a synced
`manuscript/` — it is planning, not publishable source (Core Rule). Reference
it from the manuscript. It is curated primary state — user and agent edit it
in ordinary commits: statuses and numbers update in place, never regenerated.

```markdown
# Core claim

## Exact wording
## Evidence
## Required experiments
## Figure/table support
## Known weaknesses
## Reviewer objections
## Status

# Secondary claim
```

Use this ledger to keep the paper anchored to actual evidence rather than
drifting into unsupported prose.

## Figure and Table Pipeline

Figures and tables should be reproducible artifacts.

Rules:

- Do not hand-edit generated figures/tables.
- Generated tables may be included via `\input{tables/generated/name.tex}`.
- Generated plots should normally be PDF, or SVG converted to PDF.
- Make generated artifacts BYTE-deterministic (strip embedded timestamps, e.g.
  matplotlib `savefig(..., metadata={"CreationDate": None})`) so unchanged inputs
  produce identical bytes and committed artifacts do not churn VC. Format (PDF vs
  SVG) matters less than determinism; use what the build ingests (PDF for pdflatex).
- Scripts should be runnable from the project root.
- Generated outputs should record or imply the experiment/result source.
- If results are large, keep only compact paper artifacts in `manuscript/`.
- When the manuscript is externally synced, the generators live in the code layer
  OUTSIDE it and write into `manuscript/*/generated`; commit those generated
  artifacts (the host cannot reproduce them) — see Core Rule.

## Build Commands

Prefer `latexmk` over direct `pdflatex`/`lualatex` calls.

Recommended user-facing commands:

```text
make figures
make tables
make paper
make live
make arxiv
make clean
```

`make paper` runs LaTeX from `manuscript/` via `latexmk`, with SyncTeX where it
helps. `just` equivalents are fine if the project uses it.

`make live` is for humans during active writing: a long-running continuous
rebuild/watch mode, usually `latexmk -pdf -pvc -synctex=1 main.tex`. Agents
should not use it for verification; use the one-shot `make paper` target.

## Bibliography Workflow

Prefer one authoritative bibliography source.

Common setup:

```text
paper library / reference manager / project bibliography
  -> authoritative .bib export
  -> editor citation tooling
  -> manuscript citations
```

Acceptable manuscript bibliography options:

- reference the global `.bib` directly
- symlink `manuscript/refs.bib` to the global/exported bibliography
- copy/export a submission-specific `refs.bib`

Do not fabricate citations. For literature search, related work, citation
verification, or bibliography generation, follow the host's research/citation
verification policy before producing paper-specific content.

## Agent Collaboration Pattern

Given human-owned `.tex`, use agents as reviewers and research assistants, not
as direct manuscript editors.

Good requests:

- “Read `manuscript/main.tex` and produce a section-by-section revision plan.”
- “Compare `notes/claims.md` against the current experiments and flag unsupported claims.”
- “Inspect the LaTeX build log and summarize errors/warnings.”
- “Suggest better related-work positioning, with verified citations.”
- “Check whether figures and tables support the abstract claims.”
- “Draft proposed edits in a project `notes/` HTML working note, not in `.tex`.”

If asked for direct `.tex` edits, provide a human-applyable proposal instead.

## Rebuttal and Camera-Ready Workflow

For rebuttals/revisions, keep reviewer-response work separate from final source
until decisions are made:

Keep rebuttal/revision plans outside the portable `manuscript/` boundary, e.g.
as project `notes/` HTML working notes. The manuscript directory should contain
only the final compile-standalone artifact unless the user establishes a project
policy that explicitly exempts review files from sync/publish packaging.

Agents may help classify comments:

- must fix
- should fix
- optional
- misunderstanding to clarify
- out of scope

Triage against the window, not against reviewer order. The response period is
fixed and short, so rank by weight-on-the-decision over cost-to-answer and start
where a cheap answer defuses a strong objection. A point raised by two reviewers
outranks a longer one raised by one.

- **Show, do not promise.** A rebuttal presenting a result beats one undertaking
  to add it, and a commitment you cannot land by camera-ready is worse than a
  clean concession. Estimate the experiment against the remaining days BEFORE
  offering it.
- **Concede early and plainly where the reviewer is right.** Contesting every
  point reads as non-responsive, and words spent defending a weak point are
  taken from the strong ones.
- **A misunderstanding is usually a writing failure.** Answer it, then name the
  text change that stops it recurring — "clarified in §3.2" is the part that
  actually resolves it.
- **Rebuttal experiments are still experiments.** Seeds, pairing, and the
  selection rules apply unchanged (`research-run`); a number produced at one seed
  to hit the deadline is the standard way to make the review worse. If it cannot
  be done properly inside the window, say so rather than running it badly.
- Keep a claim-by-claim map from reviewer point → evidence → text change in the
  planning area. That map is what makes the camera-ready pass mechanical instead
  of a re-read of every thread.

But final text changes remain human-owned unless the user explicitly changes
the project policy as described in the `.tex` guardrail.

## Checklist for Setting Up a Manuscript

1. Inspect the existing project layout; locate result directories and experiment
   entry points.
2. Propose the `manuscript/` skeleton, build commands, bibliography source, and
   generated figure/table paths.
3. Create or recommend the claims/evidence ledger in the planning area.
4. Report the proposed layout and next actions BEFORE implementing.
5. If it will be synced or shipped, apply both Core Rules.

## Related Skills

- `research-protocol` before any citation, related-work, or bibliography content.
- `context-project-docs` for where `notes/` and standing project docs belong.
- `dev-viz` for the figure generators feeding `figures/generated/`.
- `research-run` for the results those figures and tables report.
