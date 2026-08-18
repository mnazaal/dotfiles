---
name: research-plan
description: Use when writing or revising a research-project plan document (PLAN.md): framing, decision records, novelty lit-gate, experiments, execution order, risks.
---

# Skill: Research Plan

## Purpose

Write a research-project plan that records decisions, pins dependencies, and
gates novelty claims — so a later session can start cold from the document.

Use only after the direction is chosen. If pursue/park/kill is still open, route
to `research-session`; if decisions are unresolved, route to `plan-interview`.

## Rules

- The plan records decisions and rationale, not open options.
- Section shape: setting/framing → decisions with rationale → core
  model/derivation → pinned dependency API surface → baselines + experiments
  → repo shape → execution order → early tests → open risks → decision log.
- Execution order starts with a mandatory step-0 novelty lit-search gate
  (`research-protocol`); mark novelty UNVERIFIED under risks until it runs,
  and list pivot options in case it fails. Gate the load-bearing ablation
  early too — run its cheapest form, or the empirical precondition it needs
  (does the mechanism's phenomenon occur at decision-relevant prevalence in
  real data?), BEFORE building the full method. It is the real go/no-go;
  building first risks polishing a dead thesis.
- Record each hard-to-reverse decision in the decision log, as the question a
  future reader would ask, with the rejected alternatives.
- An execution-order item that tempts scope creep carries its anti-scope
  inline ("extract the two helpers; do not add a state-machine layer") — the
  non-goal travels with the task a future session will actually read, not only
  in the decision log.
- Pin upstream API surfaces exactly (module paths, function names); flag
  anything unverified as a scaffold-time task rather than guessing.
- Name the load-bearing ablation: the experiment separating the claimed
  mechanism from the nearest cheap heuristic — pitted against the *strongest
  fair* form of that heuristic (a win over a strawman baseline is a false
  positive), with ground truth not derived from the method under test.
- State what graduates to the shared library vs stays project-side
  (promote on second duplication).
- Unpublished-idea privacy: the plan lives in the project repo, never in a
  to-be-published library's docs/ or git history.

## Revision: One Plan, Not a Stack of Plans

A pivot REVISES the plan. It never appends a second dated copy of the section
shape — that is how a plan grows past the point of answering anything.
Sections divide by cardinality:

- **Single-valued — exactly one, rewritten in place.** Framing, core
  model/derivation, pinned API surface, baselines + experiments, repo shape,
  execution order, early tests, open risks. Two live execution orders means
  the plan no longer says what to do next; a resolved risk is not a risk; a
  stale pin is worse than no pin, because it is trusted.
- **Append-only — the one section that grows.** The decision log.

When a pivot lands: rewrite the affected single-valued sections, append one
decision-log entry for what changed and why, and move any result the work
produced — including a branch that died — to `LOG.md` as a verdict
(`research-run`). A dead branch is a result, not a plan section; left in place
with its own execution order it is indistinguishable from live work.

Gate the revision at both ends, and detect by STATUS MARKER, not by heading —
the worst accretion is headingless. Scan the whole file, including the region
above the first heading (a plan can carry a third of its content there with no
headings at all).

Count only **unmarked** forward-looking sets. A block carrying `DONE`,
`RESOLVED`, `PARKED`, `SUPERSEDED`, or its own recorded outcome is history, not
a rival — a finished phase is not ambiguous, and counting it is the fastest way
to make this gate something you ignore. What actually counts:

- two or more UNMARKED forward-looking sets (`NEXT`, `PENDING`, execution
  order, open risks);
- two sections both self-declaring `LIVE`, or many declaring nothing;
- dated pivot blocks that re-run the section shape at any heading level.

Judge a block by its status, not its title: a heading containing "framing" or
"baselines" is not a second framing section.

This gate is a READ, not a grep. Completion is recorded inconsistently — at the
step, in prose, in a status line, or only in `LOG.md` — so no pattern separates
a finished phase from a rival plan reliably; every mechanical proxy tried so far
over-fires in both directions. Open each candidate block and decide. If you find
yourself counting matches, you are measuring the wrong thing.

If the file fails on entry, STOP and report the competing threads; do not guess
which is live. Nineteen `NEXT` markers with one marked superseded have no
determinable target, and rewriting the wrong one silently deletes live work.
Compaction is a separate pass, confirmed by the user. On exit, exactly one
unmarked live set survives.

## Decision Log

The append-only home for hard-to-reverse decisions. Default to a
`## Decision log` section in `PLAN.md`; honor `docs/adr/` instead when the
project already uses it. Never both.

One dated entry per decision: the question a future reader would ask, the
choice, the rejected alternatives and why, and a status — live, or superseded
by ⟨entry⟩.

Superseding edits the old entry's status line and appends a new entry; it
never rewrites or deletes the original. The rationale for a choice you later
reversed is the most expensive thing to reconstruct.

A decision entry that invalidates a single-valued section is not complete until
that section is rewritten. Appending the entry and leaving the execution order,
experiment list, or theory section describing the superseded choice yields a
plan whose log and body disagree — and the body is what gets executed. Name the
affected sections in the entry, then edit them in the same pass. This is
distinct from the revision gate above: that gate catches *rival* live plans,
this catches *unpropagated* ones, which pass it silently.

## Workflow

1. Confirm the direction is settled and identify the target `PLAN.md` governed by `context-project-docs`.
2. If `PLAN.md` already exists this is a revision, not a new plan — rewrite the affected single-valued sections rather than appending a dated one.
3. Run or schedule the step-0 novelty gate before treating novelty as verified.
4. Draft or rewrite decisions, rationale, execution order, and risks; keep unresolved choices out of the plan or mark them explicitly as risks.
5. Append a decision-log entry per hard-to-reverse call; route results and dead branches to `LOG.md`.
6. Grep for duplicate single-valued headings, then persist only with user/policy authorization and report unresolved risks and the next action.

## Related Skills

- `context-project-docs` for the standing-document set PLAN.md belongs to.
- `plan-interview` for resolving decisions before writing.
- `research-protocol` for the lit-gate and citation verification.
- `research-lit-search` for the step-0 sweep itself.
- `research-run` for the verdict blocks that dead branches and results move to.
- `dev-python` for the repo scaffold conventions.
