---
name: dev-borrow-design
description: "Use when an established project is being mined for what to adopt into the user's own: what can we learn from repo X, borrow or steal patterns from X, compare our design against X, should we refactor Y the way X does it, survey this library or skill-repo or config for transferable ideas. Ends in a ranked adoption list plus rejects with reasons, not a tour of X."
---

# Skill: Dev Borrow Design

## Purpose

Mine a reference project X for what the user's own project Y should adopt, inside
Y's stated architectural constraints. Y may be a library, a configuration, or a
set of agent skills; X is usually well regarded, which is exactly why an
unconstrained read of it produces a refactor list nobody asked for.

The deliverable is a ranked adoption list, the rejects with their reasons, and —
where X's design is genuinely better for Y's goals — a costed architectural
proposal. Reading X is the cheap half.

## Before reading X

- **Write Y's constraints down first**, in the user's words where they gave them:
  what Y is for, its architectural commitments, what it deliberately refuses to
  do. Every candidate is judged against that list. Without it, every pattern in a
  respected project looks adoptable.
- **Inventory what Y already has.** The cheapest reject is *already present under
  another name*, and it is only cheap if found before the proposal is written.
- **Check whether X was surveyed before.** A prior survey's reject list is the
  point of writing one; re-deriving it wastes the run and re-proposes what the
  user already refused.
- If the user named a specific pain, X is being read for that one thing. If not,
  the sweep is open and the ranking carries the judgement.

## Reading X

- **Provenance before ideas.** Licence, author, last commit date, commit count,
  tests, CI — and whether the checkout is the user's work or a pristine
  third-party clone. Licence decides whether text and source may be copied with
  attribution or must be reimplemented from the idea; no tests, no CI, or a stale
  HEAD downgrades every claim X makes about itself.
- **Verify claims against X's source, not its README.** Config that nothing
  loads, documented features nothing wires up, and headline numbers not
  reproducible from the repo are common in admired projects. A
  documented-but-unwired feature is a finding about X, never a transferable.
- **Judge each decision against the problem X had.** A mechanism can be excellent
  there and dead weight in Y because Y already has what X was missing —
  `dev-ponytail` owns that premise check, and it applies to every candidate.
- Fan out with subagents when X is large or several X's are being compared: one
  per source or per subsystem, each returning `file:line`-cited claims. Spot-check
  citations against the source before any of it enters the report
  (`agent-orchestration`).

## Four verdicts

Every candidate lands in exactly one, and all four go in the report:

- **Transferable** — adoptable into Y as it stands, at a stated cost.
- **Convergent evidence** — X independently made, or refused, a decision Y already
  made. Not adoptable; it is confirmation or a warning, and it is the finding most
  often dropped on the floor.
- **Y is ahead** — X lacks something Y has. Recording it is what answers the next
  "should we add Z?".
- **Reject** — with the reason preserved: conflicts with a named constraint, its
  premise is absent here, already present in Y, or X is simply wrong. A reject
  whose reason is lost comes back as a proposal at the next survey.

A survey with no rejects means the constraint list was not used.

## Ranking

Rank by adoption cost, not by how impressive the idea is, and name each item's
rung — the user's go/no-go differs per rung:

1. Prose or config edits to something that already exists.
2. A contained change inside an existing module, script, or check.
3. A new artifact, a new dependency, or a migration.

Prefer rung 1 phrasing of a rung 3 idea where one exists. Anything on rung 3
justifies its own existence before it justifies its resemblance to X
(`dev-ponytail`).

## Architectural proposals

When X's design is better for Y's stated goals and not merely different, say so
plainly, and cost it in the same breath:

- Which files change, what breaks, whether it is reversible.
- The strongest objection to it, surfaced unprompted (`critique-argument`).
- The cheaper partial adoption, named separately. A full refactor and the version
  that needs no migration are two different offers, and merging them forces the
  user to reverse-engineer which one they are approving.

One proposal at a time. A survey that ends in three simultaneous refactors gets
none of them.

## Delivery

- Nothing is applied during a survey. Reading X is read-only, and adoption is a
  separate, per-item approval — the user approves items, not surveys.
- Record the ranked list, the rejects with reasons, and the provenance flags
  where they will be found again (`context-project-docs` for a project's own
  notes). The record is what makes the next survey cheaper instead of identical.
- Report which of X's claims were verified against source and which were taken on
  trust (`dev-verification`).

## Anti-Patterns

- Touring X: an architecture summary in place of a ranked list. `dev-scout` and
  `understand-codebase` already do that better, and neither is what was asked.
- Adopting X's vocabulary — names, file layout, idioms — without the structure
  that made them mean something.
- A transferable that, read closely, is "rewrite Y as X".
- Proposing what Y's constraints already forbid, then arguing the constraint.

## Related Skills

- `dev-scout` to map X read-only; `understand-codebase` when the goal is to
  understand X rather than mine it for Y.
- `dev-ponytail` for the premise check and for whether a transferable should
  exist at all.
- `critique-argument` to stress-test an architectural proposal before it reaches
  the user.
- `agent-orchestration` for the fan-out and for verifying delegated findings.
- `meta-skills-improve` when Y is the user's own agent skills or agent config —
  it owns placement, firing, and the no-op test for that target.
- `dev-jax-port` when adoption stops being design transfer and becomes a
  line-by-line port with parity requirements.
- `decide-priority` to sequence an accepted list against other work.
- `context-project-docs` for where the survey record lands.
