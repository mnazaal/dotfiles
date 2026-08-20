---
name: research-map
description: Use when asked to map out a project, understand the full project, or point to the code implementing each part; also for paper-to-codebase mapping, architecture/dataflow overview, mermaid diagrams, equation-to-code mapping, paper-code divergences. Sinks - chat, README's stamped Overview block, or the full form as notes/main.html.
---

# Skill: Research Map

## Purpose

Regenerate-on-demand orientation for a research project: what the paper claims, how the code realizes it, and where they disagree. Output is derived fresh from the current code and paper. Three sinks: emit to chat for your own orientation, write the gist into README's delimited Overview block (`context-project-docs`) as the shareable snapshot, or write the full form as `notes/main.html` — the project's front-door note. The chat form can't go stale; each persisted form carries a provenance stamp so its staleness is visible and it is regenerated, never hand-edited.

## Workflow

1. Read project state if present: `PLAN.md`, `CONTEXT.md`, README.
2. Skim the paper via `research-paper` (`context-pdf` for extraction): problem, method, key equations/algorithms.
3. Scout the repo via `dev-scout`: entry points, modules, seams.
4. Build the concept→code map: paper concept/equation/algorithm → code location (e.g. "Eq. 7 ELBO → `losses.py:elbo`", "Algorithm 1 → `train.py:fit`").
5. Draw 1–2 small mermaid diagrams: architecture (modules and dependencies) and/or dataflow (data → transforms → model → metrics).
6. List paper↔code divergences: in-code-but-not-in-paper, in-paper-but-missing, silently different (defaults, approximations, extra tricks).

## Output Shape

Same content, three sinks:

- **Chat** (default, for orientation): orientation summary (≤10 lines); concept→code table; mermaid diagram(s) in fenced blocks; divergences, each with `file:line` and paper-section evidence. Plain-text math — chat renders no LaTeX.
- **README Overview block** (the shareable snapshot): write the summary + mermaid diagram + concept→code table between the markers, replacing whatever was there. Divergences stay out of README (they are working notes, not the gist).
- **`notes/main.html`** (the full form, when asked to persist the map): everything — summary, concept→code table, mermaid, divergences, and real math (self-contained HTML with inline MathJax, per the global notes convention). Replace the whole file on regeneration; open with the provenance stamp and pointers to `notes/claims.md` and `PLAN.md` (`context-project-docs` owns the reserved name).

```markdown
## Overview
<!-- research-map:begin (generated from a1b2c3d, 2026-07-03) -->
  …summary, mermaid, concept→code table…
<!-- research-map:end -->
```

Stamp every persisted write (README block and `main.html` alike) with `git rev-parse --short HEAD` and today's date.

## Rules

- Three sinks only: chat, README's `research-map:begin/end` block, or `notes/main.html` — the latter two after loading/following `context-project-docs`. Never create a new standing doc (`OVERVIEW.md`/`MAP.md`) and never hand-write an overview elsewhere — a persisted form is stamped and regenerated or nothing.
- Read-only on code: the only files this skill writes are README (only between its markers) and `notes/main.html` (whole-file replace). Never edit code, and never touch README outside the block.
- If HEAD has moved past a persisted stamp, treat that copy as stale and regenerate rather than trusting it.
- Diagrams stay small (≤ ~12 nodes); split rather than cram.
- Claims about the paper follow `research-protocol`; a divergence is evidence-backed, not a vibe.
- Surface divergences as findings; route suspected silent bugs to `debug-ml-research`, doc staleness to `context-project-docs`.

## Related Skills

- `research-paper` for the paper side; `context-pdf` for extraction.
- `dev-scout` for the code side.
- `debug-ml-research` when a divergence looks like a silent bug.
- `context-project-docs` for README's place in the canonical doc set.
