---
name: dev-viz
description: Use before writing or regenerating a manuscript figure or generated table, before plotting a result, and before referencing or captioning a float. Covers generated figure/table artifacts and the producers that write them, plots, charts, column-width sizing, font matching, error bars and seed variability, dashboards, palettes, legends, matplotlib, seaborn, plotly, network graphs, pgfplots, colorblind-safe design, export formats.
---

# Skill: Dev Viz

## Rules

- Use colorblind-safe categorical palettes and perceptually uniform sequential maps.
- Never rely on color alone; add labels, markers, line styles, shapes, or annotations.
- Prefer vector output for plots and paper/document figures unless raster is required.
- Match project/document export pipeline.

## Paper Figures

A manuscript figure is a typeset element, not an image. These are the parts that
do not follow from general plotting sense.

- **Size in the script, not in LaTeX.** Set `figsize` in inches to the target
  column or text width and emit at final size. Scaling with
  `\includegraphics[width=...]` rescales the text too, so each figure lands at a
  different effective font size — the usual reason a paper's figures look like
  they came from different papers.
- **Match the document's type.** Set font family and size to the body text once,
  in a shared style module every figure script imports. Per-script rcParams is
  how a manuscript acquires six fonts.
- **Plot the quantity the claim is about.** For a two-arm comparison over seeds,
  show the paired per-seed difference and its interval — not two overlapping
  mean±std bands. Overlapping bars are not the test in either direction
  (`research-run`); a figure supporting a significance claim should show the
  difference the claim is about.
- **Show n, and say what the interval is.** Number of seeds behind every error
  bar, and whether it is SD, SEM, or a bootstrap CI. They differ by large
  factors and are indistinguishable by eye, so an unlabelled bar is unreadable
  evidence.
- Generated figures and tables are build artifacts: regenerate, never hand-edit.
  The generator stays outside a synced manuscript directory, and the committed
  artifact must be byte-deterministic — `research-manuscript-workflow` owns both
  rules.

### How the prose uses a float

Producing the figure is half of it; the other half is how the text points at
it. Each rule with the shape its violation takes:

- **Every float is referenced and discussed.** *Violation:* a figure present
  in the document and never `\ref`'d; a table cited once with nothing said
  about what it shows.
- **The reference says what to look for.** Name the pattern, the comparison,
  or the direction the reader should take away. *Violation:* a bare "as shown
  in Figure 3", which asserts the figure exists and leaves extracting its
  message to the reader.
- **Figure, caption and text agree.** Same terminology for the same element,
  and positional claims that match the rendering. *Violation:* text saying
  "top-left" for something rendered bottom-right; a caption describing an
  element the figure does not contain.
- **The caption stands alone.** It states what is shown, expands the symbols
  and abbreviations appearing in the figure, gives units, and names the
  takeaway — readers scan floats before deciding to read the prose.
  *Violation:* "Results on dataset X"; a caption leaning on a term defined
  only in the body; a caption narrating layout ("Left: …, Right: …") without
  saying what it means.
- **Subfigure rows align at the top.** Use `[t]` on subfigures in multi-row
  grids and pin `\includegraphics[height=…]` when a row mixes aspect ratios.
  *Violation:* the template's default `[b]`, which staggers a row as soon as
  one subfigure carries a caption and its neighbours do not.

## Generated Tables

A table is where the paper's numbers are actually read, so its failures are
arithmetic rather than aesthetic. `research-manuscript-workflow` owns where a
generated table lives, how it is committed, and what a provenance comment inside
one may name; these are rules for what the producer emits.

- **Emit a bare `tabular`, not a float.** The generator writes the rows; the
  human-owned source keeps the float environment, placement, caption and label.
  A generator emitting the whole float takes caption wording away from the
  author, and takes it back on every regeneration.
- **Mark which column is the comparison of interest.** A grid reports many cells
  and exactly one of them was the question; the rest are descriptive. Marking it
  is what stops the best cell being read as the result — `research-run` owns why
  it has to be named before the runs rather than after.
- **A cell reporting a comparison carries n and names its interval.** The same
  rule as figures (Paper Figures); a table hides a missing one more easily,
  because the number still looks complete without it.
- **Bold marks the pre-registered winner, not the largest number.** Emphasis
  chosen after seeing the cells is a selection the reader cannot see. Either drop
  it, or state what was selected and over how many cells.
- **Round to the interval, not to a fixed width.** Digits past the interval's
  leading significant figure are noise typeset as precision: `0.6931 ± 0.05`
  claims two digits the data does not support.

## Workflow

1. Identify audience and output medium.
2. Choose encoding before styling.
3. Pick accessible palette and non-color redundancy.
4. Add labels, units, legend, and caption-ready context.
5. Save/export in requested or project-appropriate format.

## Related Skills

- `research-run` for interpreting plots/metrics, and for why the paired difference is the quantity to plot.
- `research-manuscript-workflow` for the figure and table pipeline: generator placement, committed artifacts, byte-determinism.
