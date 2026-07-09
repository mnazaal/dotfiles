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
  → repo shape → execution order → early tests → open risks.
- Execution order starts with a mandatory step-0 novelty lit-search gate
  (`research-protocol`); mark novelty UNVERIFIED under risks until it runs,
  and list pivot options in case it fails. Gate the load-bearing ablation
  early too — run its cheapest form, or the empirical precondition it needs
  (does the mechanism's phenomenon occur at decision-relevant prevalence in
  real data?), BEFORE building the full method. It is the real go/no-go;
  building first risks polishing a dead thesis.
- Record hard-to-reverse decisions inline as the question a future reader
  would ask, with the rejected alternatives.
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

## Related Skills

- `context-project-docs` for the standing-document set PLAN.md belongs to.
- `plan-interview` for resolving decisions before writing.
- `research-protocol` for the lit-gate and citation verification.
- `research-lit-search` for the step-0 sweep itself.
- `dev-python` for the repo scaffold conventions.
