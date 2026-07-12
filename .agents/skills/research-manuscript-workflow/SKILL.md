---
name: research-manuscript-workflow
description: Use for ML/scientific paper writing workflows: LaTeX manuscript directories, paper skeletons, generated figures/tables, citation setup, arXiv/camera-ready preparation, and agent-safe manuscript collaboration.
---

# Skill: Research Manuscript Workflow

## Purpose

Use for ML/scientific paper writing workflows: LaTeX manuscript directories,
paper skeletons, generated figures/tables, citation setup, arXiv/camera-ready
preparation, and agent-safe manuscript collaboration.

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
      source/
      generated/
    tables/
      generated/
    macros.tex
    notation.tex
    latexmkrc
    Makefile
```

`manuscript/` is the publication-facing layer. It should consume outputs from
code, experiments, notes, and bibliography tooling, not replace them.

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
- `figures/source/`: figure-generation scripts or figure source assets
- `figures/generated/`: deterministic generated figure outputs
- `tables/generated/`: deterministic generated table outputs
- `claims.md`: claim/evidence/reviewer-objection ledger
- `latexmkrc`: build settings
- `Makefile`: paper build commands

Keep generated files clearly separated from human-authored files.

## Claims and Evidence Ledger

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
- Scripts should be runnable from the project root.
- Generated outputs should record or imply the experiment/result source.
- If results are large, keep only compact paper artifacts in `manuscript/`.

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
- “Compare `claims.md` against the current experiments and flag unsupported claims.”
- “Inspect the LaTeX build log and summarize errors/warnings.”
- “Suggest better related-work positioning, with verified citations.”
- “Check whether figures and tables support the abstract claims.”
- “Draft proposed edits in `manuscript/revision-plan.md`, not in `.tex`.”

Bad requests:

- “Rewrite the introduction in place.”
- “Edit all `.tex` files for clarity.”
- “Fix the theorem statement directly.”
- “Automatically update citations in the paper.”

If asked for direct `.tex` edits, provide a human-applyable proposal instead.

## Rebuttal and Camera-Ready Workflow

For rebuttals/revisions, keep reviewer-response work separate from final source
until decisions are made:

```text
manuscript/
  reviews/
    reviewer_1.md
    reviewer_2.md
    response_plan.md
    camera_ready_checklist.md
```

Agents may help classify comments:

- must fix
- should fix
- optional
- misunderstanding to clarify
- out of scope

But final text changes remain human-owned unless the user explicitly changes
the project policy.

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

## Portability Notes

- Keep this workflow independent of any one editor, package manager, agent
  harness, or personal bibliography database.
- Follow the host environment's routing for citations, documentation, security,
  verification, and project-specific toolchains.
- Prefer project-local conventions over personal defaults when they conflict.
