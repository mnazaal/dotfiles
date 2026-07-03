---
name: dev-viz
description: Use for visualization code: plots, charts, figures, dashboards, palettes, legends, matplotlib, seaborn, plotly, network graphs, pgfplots, colorblind-safe design, export formats.
---

# Skill: Dev Viz

## Rules

- Use colorblind-safe categorical palettes and perceptually uniform sequential maps.
- Never rely on color alone; add labels, markers, line styles, shapes, or annotations.
- Keep legends explicit, axes labeled, and contrast high.
- Prefer vector output for plots and paper/document figures unless raster is required.
- Match project/document export pipeline.

## Workflow

1. Identify audience and output medium.
2. Choose encoding before styling.
3. Pick accessible palette and non-color redundancy.
4. Add labels, units, legend, and caption-ready context.
5. Save/export in requested or project-appropriate format.

## Anti-Patterns

- Rainbow maps for ordered values.
- Categories distinguished by color only.
- Unlabeled axes or ambiguous units.
- Raster-only output for line art meant for papers.

## Related Skills

- `research-run` for interpreting plots/metrics.
- `context-org` for org/LaTeX export conventions.
