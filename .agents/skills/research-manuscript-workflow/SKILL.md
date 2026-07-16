---
name: research-manuscript-workflow
description: Use for ML/scientific paper writing workflows: LaTeX manuscript directories, paper skeletons, generated figures/tables, citation setup, arXiv/camera-ready preparation, and agent-safe manuscript collaboration.
---

# Skill: Research Manuscript Workflow

## Purpose

Set the safety and portability boundaries for ML/scientific manuscript work.
For citation or related-work content, load `research-protocol` first.

## When to Use

Load this skill when the user asks about:

- setting up a `manuscript/` or paper directory
- writing a scientific/ML paper in LaTeX
- organizing figures, tables, experiments, and paper text
- arXiv, workshop, conference, camera-ready, or rebuttal workflows
- editor/citation/build tooling for paper writing
- turning an existing research project into a manuscript
- agent-safe workflows for editing or reviewing paper drafts

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

This is optional, provider-specific troubleshooting. Verify the current provider
behavior and repository state before any destructive recovery path.

When the synced directory is a monorepo subdir pushed to a hosted LaTeX git
bridge (Overleaf is the common case), the bridge is locked down — plan for it:

- Its default branch is usually `main` (not `master`); it typically FORBIDS
  `--force` and pushing new branches, and requires a linear history built on its
  initial commit.
- `git subtree push` from a PRE-EXISTING subdir never fast-forwards (its split
  doesn't share the host's first commit) and force is rejected. Fix: a one-time
  `subtree add` re-seed — drop the prefix (`git rm -r <dir> && commit`, THEN
  `rm -rf <dir>`: `git rm` leaves untracked/ignored files like `build/`, so the
  dir survives on disk and `subtree add` refuses with "prefix already exists"),
  `git subtree add --prefix=<dir> <remote> main`, restore your content, then push.
- Recurring: `git subtree pull` / `push` (wrap as `make <host>-pull` / `-push`).
  Two rules: **pull before push**, and **commit before push** (subtree only sends
  committed state). Sync from the integration branch (usually `main`) — the sync
  boundary is the `--prefix` **subdir**, NOT a branch, so keep no dedicated
  manuscript/host branch; any seed / re-seed branch is one-time throwaway
  scaffolding, deleted once the re-seed lands (a long-lived one is pure bookkeeping).
- The committed generated artifacts (Core Rule) ride along automatically — no
  force-add.
- **Scope check (external-sync safety).** Only the `--prefix`'d subdir crosses to
  the host. After a push, inspect the actual remote tree (`git ls-tree <host>/main`)
  and confirm ZERO parent-repo paths (`src/`, tests, lockfiles) — `--prefix=<dir>`
  on every push/pull is the boundary; the sole leak vector is a bare `git push
  <host>` of the whole repo (which the bridge shape rejects anyway). Verify the
  tree, don't assume it.

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
externally synced or must be portable, apply the Core Rule above: generators move
to the code layer (`scripts/`), generated artifacts are committed, and the claims
ledger lives in the planning area (`notes/`) — so `manuscript/` holds only the
compile-standalone artifact.

Do not put the full paper under `docs/` unless the project already uses `docs/`
as its publication area. `docs/` should usually remain for technical/internal
documentation and related documents.

Do not split the manuscript into a separate repository unless collaboration,
publisher requirements, or artifact submission constraints require it.

## Manuscript Contract

A good manuscript directory has one clear purpose: produce the paper artifact.

Recommended components:

- `main.tex`: top-level LaTeX entry point
- `sections/`: human-authored paper sections
- `macros.tex`: commands/macros
- `notation.tex`: notation table or shared symbols
- `figures/source/`: figure source assets (generators move to the code layer when the manuscript is synced — see Core Rule)
- `figures/generated/`: deterministic generated figure outputs (committed when synced)
- `tables/generated/`: deterministic generated table outputs (committed when synced)
- `latexmkrc`: build settings
- `Makefile`: paper build commands (pure `latexmk` when synced — no pipeline reachout)

The claims/evidence ledger is NOT listed here: it is planning, not publishable
source, so it lives in the project planning area (`notes/`), not a synced
`manuscript/` — see the Claims and Evidence Ledger section. Keep generated files
clearly separated from human-authored files.

## Claims and Evidence Ledger

Keep this ledger in the project's planning area (e.g. an HTML working note in
`notes/` per global policy), not inside a synced `manuscript/` — it is planning,
not publishable source (Core Rule). Reference it from the manuscript.

```html
<h1>Core claim</h1>

<h2>Exact wording</h2>
<h2>Evidence</h2>
<h2>Required experiments</h2>
<h2>Figure/table support</h2>
<h2>Known weaknesses</h2>
<h2>Reviewer objections</h2>
<h2>Status</h2>

<h1>Secondary claim</h1>
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

If the project uses `just`, equivalent commands are fine:

A good `make paper` target should:

- run LaTeX from `manuscript/`
- use `latexmk`
- enable SyncTeX when useful
- fail loudly on build errors
- avoid deleting generated paper artifacts accidentally

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

## Editor Workflow

Use whichever editor/tooling the project standardizes on. A good scientific
writing setup should provide:

- LaTeX-aware editing and build integration
- fast insertion of math, environments, labels, references, and citations
- source/PDF synchronization when available
- spell checking and optional prose/style linting
- focused prose layout for long-form writing
- version-control diff review
- PDF review and annotation support

Suggested division of labor:

- planning notes: claims, outlines, derivations, reviewer TODOs
- LaTeX: final paper source
- BibTeX/BibLaTeX: references
- generated artifacts: figures/tables from scripts/results

## Agent Collaboration Pattern

Given human-owned `.tex`, use agents as reviewers and research assistants, not
as direct manuscript editors.

Good requests:

- “Read `manuscript/main.tex` and produce a section-by-section revision plan.”
- “Compare `notes/claims.html` against the current experiments and flag unsupported claims.”
- “Inspect the LaTeX build log and summarize errors/warnings.”
- “Suggest better related-work positioning, with verified citations.”
- “Check whether figures and tables support the abstract claims.”
- “Draft proposed edits in a project `notes/` HTML working note, not in `.tex`.”

Bad requests:

- “Rewrite the introduction in place.”
- “Edit all `.tex` files for clarity.”
- “Fix the theorem statement directly.”
- “Automatically update citations in the paper.”

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

But final text changes remain human-owned unless the user explicitly changes
the project policy as described in the `.tex` guardrail.

## Checklist for Setting Up a Manuscript

When setting up a project manuscript workflow:

1. Inspect existing project layout.
2. Identify result directories and experiment entry points.
3. Recommend a `manuscript/` skeleton.
4. Define build commands.
5. Connect bibliography source.
6. Define generated figure/table paths.
7. Create or recommend a claims/evidence ledger.
8. Preserve the `.tex` no-edit boundary.
9. Report the proposed layout and next actions before implementation.
10. If the manuscript will be git-synced (Overleaf) or shipped (arXiv), enforce
    the Core Rule: generators outside the synced boundary, generated artifacts
    committed, claims ledger in the planning area.

## Portability Notes

- Keep this workflow independent of any one editor, package manager, agent
  harness, or personal bibliography database.
- Follow the host environment's routing for citations, documentation, security,
  verification, and project-specific toolchains.
- Prefer project-local conventions over personal defaults when they conflict.
