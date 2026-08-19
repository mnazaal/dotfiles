---
name: understand-codebase
description: Use to build a working understanding of a codebase for the human rather than the agent: walk me through this library, what is the public API, how does this actually work, what is this abstraction for, which parts are vendored or ported, what would break if I deleted this. Covers code written with agent help, inherited code, and third-party code being adapted, reproduced, or evaluated as a dependency.
---

# Skill: Understand Codebase

## Purpose

Transfer a codebase's design into the user's head at the depth where they can
justify it: what the public surface is, how one real call flows through it, and
which parts they could not defend if asked. Then record what the code failed to
explain about itself.

The reason the user is lost is rarely missing documentation. It is that the
design decisions were made somewhere they never saw — incrementally by an agent,
by a predecessor, or by an upstream author — and never landed anywhere legible.

## Rules

- Read the public surface before the implementation. Implementation only makes
  sense in terms of what it must support.
- Ground every statement in `file:line`. Never explain the code from what was
  said earlier in the conversation.
- Prefer showing the smallest runnable thing over describing it in prose.
- For code the user did not write, the upstream reference — paper, docs, release
  notes, issue history — is the source of truth for *intent*; the code is
  evidence only of what was actually built. Where they disagree, say so rather
  than reconciling them silently.
- Diagnose before teaching. Ask what the user believes, then teach to the
  difference. Do not grade the answer — use it to locate the gap.
- One question at a time.
- Gather structure with `dev-scout` rather than re-deriving it here. This skill
  owns the delivery, not the mapping.
- Persist as repairs to the code and its documents, never a new standing
  document. For code the user cannot write to, hand the defects back as findings
  — or an upstream issue, if they want to file one.

## Orientation

1. **Public surface** — exported symbols (package exports, `__init__.py`,
   `index.*`, public headers), CLI entry points, README usage, examples, and
   tests read as usage. What can a caller actually do?
2. **One end-to-end trace** of the single most-used path, entry to result.
3. **Structure** via `dev-scout`: entry points, seams, adapters, generated
   directories.
4. **Churn** — `git log` on the largest modules. Where the design is still
   moving is where any existing understanding is most likely stale.

Report ~15 lines: what the library is for, its public surface, the one path that
matters, and which areas are still moving.

## Diagnostic Questions

Aim at what is expensive to be wrong about:

- What would you tell a new user to call, and what do they get back?
- Where does control enter, and which single path carries most of the value?
- Which abstraction can you not justify? What would break if it were deleted —
  and if nothing would, that is the finding. In third-party code, the same
  question reads as: what problem is this solving that is not visible from here?
- Which invariants hold that are not enforced by types or tests? Those are the
  ones that break silently.
- Which parts are vendored, ported, or generated rather than authored here?
  Their behavior is defined elsewhere, and that reference stays the source of
  truth for them.

## Defects to Record

Route each; do not fix silently.

- A public entry point with no usage example anywhere → document it where the
  README's claims live.
- An abstraction with a single caller and no stated reason → `dev-ponytail`.
- A seam carrying an unenforced invariant and no test → `dev-tdd`.
- A README or docstring claim the code does not honor → `context-project-docs`,
  which treats doc/code mismatch as a top-tier gap.
- Vendored or ported code with no recorded reference version or parity evidence
  → `dev-jax-port`.
- Code implementing a paper equation that has drifted from it → `research-map`.

## Boundary

- Comprehension, not verification. Pinning behavior with tests → `dev-tdd`.
- Chasing one specific wrong behavior → `debug-root-cause`.
- An agent-facing structural map, or gathering as a sub-step of another skill →
  `dev-scout`. That skill stays terse and non-interactive because other skills
  call it; this one is the interactive human-facing layer above it.
- Equation↔code mapping and paper divergences → `research-map`.
- Reimplementing the traced behavior elsewhere rather than understanding it →
  `dev-jax-port`.
- Understanding a research record rather than code → `understand-project`.

## Anti-Patterns

- Reporting an exhaustive inventory; `dev-scout` already refuses to do that.
- Judging third-party code against conventions it never claimed to follow.
- Writing `ARCHITECTURE.md` or a walkthrough doc.

## Related Skills

- `dev-scout` for the structural gathering this delivers on top of.
- `understand-project` for the same loop aimed at a research record.
- `research-map` for paper↔code mapping and divergences.
- `dev-jax-port` when understanding a reference implementation is the prelude to
  porting it.
- `dev-ponytail` for the deletion call on an unjustifiable abstraction.
- `dev-tdd` for covering an unenforced invariant.
- `dev-tdd` when comprehension should escalate to pinned behavior.
- `context-project-docs` for README claims that no longer match.
