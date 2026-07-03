---
name: research-map
description: Use for quick project orientation: map a research paper to its codebase, architecture/dataflow overview, mermaid diagrams, equation-to-code mapping, paper-code divergences; emit to chat, or write a generated, provenance-stamped Overview block into an existing README.
---

# Skill: Research Map

## Purpose

Regenerate-on-demand orientation for a research project: what the paper claims, how the code realizes it, and where they disagree. Output is derived fresh from the current code and paper. Two sinks: emit to chat for your own orientation, or write it into README's delimited Overview block (`context-project-docs`) as the shareable snapshot. The chat form can't go stale; the persisted block carries a provenance stamp so its staleness is visible and it is regenerated, never hand-edited.

## Workflow

1. Read project state if present: `PLAN.md`, `CONTEXT.md`, README.
2. Skim the paper via `research-paper` (`context-pdf` for extraction): problem, method, key equations/algorithms.
3. Scout the repo via `dev-scout`: entry points, modules, seams.
4. Build the concept→code map: paper concept/equation/algorithm → code location (e.g. "Eq. 7 ELBO → `losses.py:elbo`", "Algorithm 1 → `train.py:fit`").
5. Draw 1–2 small mermaid diagrams: architecture (modules and dependencies) and/or dataflow (data → transforms → model → metrics).
6. List paper↔code divergences: in-code-but-not-in-paper, in-paper-but-missing, silently different (defaults, approximations, extra tricks).

## Output Shape

Same content, two sinks:

- **Chat** (default, for orientation): orientation summary (≤10 lines); concept→code table; mermaid diagram(s) in fenced blocks; divergences, each with `file:line` and paper-section evidence.
- **README Overview block** (the shareable snapshot): write the summary + mermaid diagram + concept→code table between the markers, replacing whatever was there. Keep divergences in chat, not README (they are working notes, not the gist).

```markdown
## Overview
<!-- research-map:begin (generated from a1b2c3d, 2026-07-03) -->
  …summary, mermaid, concept→code table…
<!-- research-map:end -->
```

Stamp the block with `git rev-parse --short HEAD` and today's date.

## Rules

- Two sinks only: chat, or README's `research-map:begin/end` block. Never create a new standing doc (`OVERVIEW.md`/`MAP.md`) and never hand-write an overview elsewhere — the persisted form is the stamped README block or nothing.
- Read-only on code: the only file this skill writes is README, and only between its markers. Never edit code, and never touch README outside the block.
- Stamp every README write with the source commit + date; if HEAD has moved past the stamp, treat the block as stale and regenerate rather than trusting it.
- Diagrams stay small (≤ ~12 nodes); split rather than cram.
- Claims about the paper follow `research-protocol`; a divergence is evidence-backed, not a vibe.
- Surface divergences as findings; route suspected silent bugs to `debug-ml-research`, doc staleness to `context-project-docs`.

## Related Skills

- `research-paper` for the paper side; `context-pdf` for extraction.
- `dev-scout` for the code side.
- `debug-ml-research` when a divergence looks like a silent bug.
- `context-project-docs` for README's place in the canonical doc set.
