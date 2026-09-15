---
name: dev-ponytail
description: "Use for minimal software solutions: YAGNI, simplest correct code, shortest path, dependency choices, architecture, refactors, tooling, deletion, avoid bloat/boilerplate/over-engineering. Load before adding a script, check, or tool to a repo, and before porting tooling from a sibling project."
---

# Skill: Dev Ponytail

## Ladder

1. Does this need to exist?
2. Can existing code/config solve it?
3. Can standard library/native platform solve it?
4. Can one small function solve it?
5. Only then add abstraction/dependency/framework.

## Rules

- Prefer deletion over addition.
- Porting a solution from a sibling project ports its premise too. Check the
  premise holds here before copying the mechanism: machinery that exists because
  that repo lacked something this one has is dead weight.
- No backward compatibility unless explicitly requested: no deprecation shims,
  legacy aliases, or versioned config fallbacks — delete the old surface and fix
  call sites. (`dev-python`'s re-export shim for a code move is a diff-size
  tactic during the move, not a compat promise to keep.)
- Prefer explicit code over clever abstraction.
- Prefer deep modules (Ousterhout): a few interfaces that are simple to call but
  hide significant implementation, over many shallow pass-through layers. YAGNI
  minimizes interface surface, not implementation depth — a deep module is not
  over-engineering; a shallow wrapper usually is.
- Prefer local change over global framework.
- Fix a footgun by removing or merging the knob before adding a guard; reach for a
  new type/predicate/wrapper to police misuse only as a last resort — a validator
  added to prevent a bug is new surface that can itself be wrong. (Guarding is still
  required when the knob must stay and misuse is silently corrupting.)
- Optimize for reversibility and low maintenance.
- Stop when requirements are satisfied.
- Two words for judging a design: **leverage** is how much behaviour one
  change moves (a deep module has it; a pass-through layer does not), and
  **locality** is whether the code that changes together lives together. A
  change that touches five files for one behaviour has low locality; that is
  the symptom to name, not "messy".
- **The deletion test.** For an abstraction, a config knob, a helper: delete it
  and see what breaks. If nothing does, or only its own tests do, it was
  speculative. Run the test rather than asking the question.
- **One adapter is a hypothetical seam, two is a real one.** A single
  implementation behind an interface is a guess about a second that has not
  arrived; write the interface when the second implementation exists, not
  before.

## What decays

Observed across personal tool configurations, including retirements by other
practitioners:

- **A single-source adapter behind a credential is the decay class.** One
  integration per site or per API, each with its own key, is what gets abandoned
  first — replaced by one general capability, or by nothing when the need turns
  out to have been occasional. Weigh that before building the second one.
- **Rebuilding what the runtime already knows decays even when it is large.**
  A hand-rolled reimplementation of something the surrounding tool computes
  exactly is the shape most reliably retired later, and sunk cost does not save
  it: it is retired precisely because it must chase an upstream that moves.
- **Retire references in the same pass as the thing.** A retirement that leaves
  a live document pointing at the retired thing has not finished; the pointer
  reads as current and costs the next reader the same investigation twice.

## Anti-Patterns

- Architecture for imagined future needs.
- New dependency for tiny behavior.
- General framework around one use case.
- Refactor bundled with unrelated feature.

## Related Skills

- `dev-python` or `dev-jax` for framework-specific implementation.
- `dev-tdd` for behavior-first changes.
- `decide-priority` when questioning whether work should happen.
