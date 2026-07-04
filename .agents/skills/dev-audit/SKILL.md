---
name: dev-audit
description: Use to bring an existing codebase under human-verified coverage: triage into criticality tiers, strong-audit critical units with reviewed tests, track via git-audit-coverage. For campaigns over standing/legacy code, not single AI-diff review (that's review-loop).
---

# Skill: Dev Audit

## Purpose

Drive an existing codebase to human-verified audit coverage, rigor scaled to
criticality. Distinct from `review-loop` (one AI-generated diff) — this
sequences a multi-unit campaign over standing code.

## Tiers

- A — subtly-wrong-is-silently-critical: losses, log-probs, samplers,
  transforms + Jacobians, custom gradients, normalizations, numerical
  kernels, public API; plus data/eval paths that could leak or misalign
  labels. Strong audit, 100% target, two-person.
- B — real behavior, shallow to verify or loud on failure. Read + contract test.
- C — no numerical semantics (plotting, logging, repr, serialization, CLI,
  generated). Reviewed + listed in the tier manifest; not touched, and
  excluded from the coverage denominator.

## Rules

- Triage every unit into A/B/C before auditing; record assignments in the
  tier manifest (a human decision worth pinning).
- "Audited" = read + behavior pinned by a human-reviewed test. A read-only
  stamp is not an audit.
- Characterization test first, then touch (audit-by-improving); an audit pass
  never changes behavior silently.
- Tier A commits require a second human reviewer; never self-certify.
- Coverage is process evidence, not correctness — the test suite is the
  assurance artifact. Never report a coverage % as a safety claim.
- Audit in vertical slices: a public entry point plus what it calls.

## Workflow

1. Triage: lightweight call/import view, assign tiers, get user sign-off.
2. Per Tier A/B unit: state contract (inputs, shapes, dtypes, invariants,
   math) → adversarial pass → characterization/property test (red) →
   improve/document/type (green) → commit with `Human-audited: yes`.
3. Tier C: review, list as low-risk in the tier manifest, leave untouched.
4. Track with `git audit-coverage <A/B paths>`; hold Tier A at target;
   edits to audited code auto-reopen review via blame reassignment.

## Routing

- `dev-scout` / `research-map` to comprehend an opaque unit (research-map when
  it implements a paper — the paper's properties become the tests).
- `debug-ml-research` + `dev-jax` + `critique-argument` for the adversarial pass.
- `dev-tdd` for the test-first slice.
- `dev-git` for the `Human-audited:` trailer + `git-audit-coverage`.
- `dev-verification` before claiming a unit audited.
- `decide-review` for the Tier A second-reviewer gate.
- `review-loop` to resolve inline markers on an audit diff.

## Boundary

- Owns tier criteria + campaign sequencing.
- Trailer mechanics + coverage tool live in `dev-git`.
- Single fresh AI diff → `review-loop`, not here.

## Anti-Patterns

- Uniform rigor across tiers; strong-auditing boilerplate.
- Touching working code before a characterization test exists.
- Reading "100% coverage" as "correct/safe."
- Self-certifying Tier A.

## Related Skills

- dev-git, review-loop, dev-tdd, debug-ml-research, dev-jax, dev-scout,
  research-map, critique-argument, dev-verification, decide-review.
