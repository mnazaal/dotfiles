---
name: research-talk
description: "Use when preparing a conference talk, seminar or lab-meeting slides, a thesis defense, an invited lecture, a grant pitch, or a research poster — anything where an audience evaluates the reasoning in one pass and cannot re-read. Covers what goes on a slide or panel and in what order; the file itself and the chart encoding belong to the tooling and viz skills."
---

# Skill: Research Talk

## Purpose

A talk is an argument delivered once, at someone else's pace, to people who
cannot scroll back. A paper is an argument delivered to a reader who can. Most
bad research decks are a paper redrawn — the structure that works on the page is
exactly what fails in a room.

This skill owns the content and its order. It does not own the file format, the
chart encoding, or the claims themselves.

## Rules

- **The title states the finding, not the topic.** "Sparse priors cut sample
  complexity by half" rather than "Results". The title carries the message so the
  audience gets it whether or not they parse the exhibit below it.
- **The titles alone must tell the argument.** Read them top to bottom with
  everything else hidden: if the sequence does not hold together, the deck has no
  spine and no amount of per-slide work supplies one. Run this before building
  any exhibit — it is cheap while the deck is an outline, expensive after.
- **One message per slide.** Two findings on a slide means the audience picks
  one, and it will not be the one you meant.
- **Every exhibit earns its place, by a two-way test.** Cover the exhibit and
  read the title — does it still hold? Then cover the title and look at the
  exhibit — is the takeaway obvious without narration? A failure of the first
  means the exhibit is decoration; a failure of the second means it needs an
  annotation or a sharper title.
- **Annotate the finding on the exhibit itself.** Mark the bar, point, region or
  cell the claim is about. The audience should not be searching while the
  speaker talks.
- **Assume it is read without you.** Decks get shared as PDFs and read as
  handouts. A slide that only works with narration loses its meaning the moment
  it travels.
- **Rebuild figures for the room; never paste from the paper PDF.** Manuscript
  figures are typeset for a column at reading distance: the fonts are too small,
  the caption does the explaining, and the detail is tuned for a reader who can
  lean in. Regenerate from the same producer with presentation sizing (axis
  labels around 16 pt and up), and drop the panels the talk does not use.
- **Check legibility at the final physical scale, not the design scale.** Slides
  viewed at 25% on a laptop and posters viewed at 10% in a PDF viewer both lie.
  Render at output size and check at the distance the audience will be at: poster
  title from across the hall, section headings from a couple of metres, body text
  from arm's length.
- **Budget backup slides for the questions you expect.** The objection you can
  answer with one prepared exhibit is the one that otherwise ends the session
  badly. They sit after the end, not in the flow.

## Posters

A poster is a conversation starter, not a paper at A0. The visitor gives it
seconds before deciding to stay.

- One claim, readable from a distance, before any detail.
- The layout carries a reading order; if the eye has to hunt for the entry
  point, the visitor leaves.
- What would be a methods section on paper becomes the thing you say out loud —
  leave it off and keep it in your head.

## Boundary

- Writing or editing the presentation/poster file, its layout API, templates and
  speaker notes: the tooling for that format.
- What a chart encodes — palette, error bars, scale, colorblind safety, the
  publication style module: `dev-viz`, whose rules hold here unchanged. A
  placeholder exhibit is no more acceptable in a talk than in a paper.
- Which claims may be made and what backs them: the claims ledger in
  `research-manuscript-workflow`. A talk states the same claims as the paper at
  lower resolution; it does not get a weaker evidence bar.
- Any cited work on a slide: `research-protocol`. A citation on a slide is a
  citation.

## Anti-Patterns

- Topic titles ("Method", "Experiments", "Results") — they say where you are in
  the deck, not what it shows.
- Adding a visual to a slide because a slide should have one. An exhibit that
  fails the two-way test is worse than white space.
- Bullet lists the speaker reads aloud; the audience reads faster than you talk
  and then attends to neither.
- The paper's figure order as the talk's order. The paper builds to the result;
  a talk usually opens with it.

## Related Skills

- `dev-viz` for the exhibits themselves and the shared style module.
- `research-manuscript-workflow` for the claims and numbers a talk restates.
- `research-protocol` for anything cited on a slide.
- `context-project-docs` for where a talk's planning notes live.
