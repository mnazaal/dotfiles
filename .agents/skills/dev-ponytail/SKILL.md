---
name: dev-ponytail
description: Use for minimal software solutions: YAGNI, simplest correct code, shortest path, dependency choices, architecture, refactors, tooling, deletion, avoid bloat/boilerplate/over-engineering. Load before adding a script, check, or tool to a repo, and before porting tooling from a sibling project.
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

## Anti-Patterns

- Architecture for imagined future needs.
- New dependency for tiny behavior.
- General framework around one use case.
- Refactor bundled with unrelated feature.

## Related Skills

- `dev-python` or `dev-jax` for framework-specific implementation.
- `dev-tdd` for behavior-first changes.
- `decide-priority` when questioning whether work should happen.
