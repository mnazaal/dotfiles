---
name: agent-orchestration
description: Use for multi-agent delegation: spawning subagents, parallel codebase exploration, independent research/review tasks, prompt scoping, avoiding duplicate work, and verifying delegated results.
---

# Skill: Agent Orchestration

## Purpose

Use subagents only when parallelism or fresh context improves the result more
than the coordination cost.

## When to Delegate

- Broad, independent exploration across files, repos, logs, or docs.
- Fresh-perspective review or critique of a concrete artifact.
- Repetitive searches with distinct scopes that can run in parallel.
- Research checks where independent evidence reduces bias.

Stay local for a single known file, a small edit, a narrow symbol lookup, or any
task where the delegation prompt would be longer than doing the work.

## Prompt Contract

Every delegated task states:

1. Goal and non-goals.
2. Exact scope: paths, files, repos, query terms, or artifacts.
3. Whether the subagent may edit files. Default: read-only.
4. Required output shape: findings, file:line evidence, risks, and next action.
5. Verification expected, if any.
6. Naming constraint: use descriptive task names; no opaque shorthand such as
   `P0/P1`, `T1/T2`, or `H1/H2` unless defined by the parent prompt. Subagent
   findings must remain understandable when copied without prior chat context.
7. Required skills for the delegated scope. Name each required skill explicitly;
   do not assume a subagent inherits the parent session's loaded skills.
8. Artifact requirement: the agent names the files it fetched and leaves them
   readable. A delegated agent's quoted evidence and the artifact it leaves
   behind are not the same thing — a correct quote can sit beside a file that
   cannot support it.

## Coordination Rules

- Split by independent scope, not by arbitrary steps that depend on each other.
- Launch independent agents concurrently; do not duplicate their assigned work
  locally while they run.
- Keep one owner for integration decisions in the parent context.
- Treat subagent output as evidence, not truth: inspect cited files, diffs, or
  artifacts before claiming completion (`dev-verification`).
- Verify a delegated fact before it enters a commit message, a plan, or a claim.
  Propagation is where an unchecked report stops being cheap to retract.
- If agents disagree, resolve with the smallest direct check, not a tie-break by
  confidence or verbosity.

## Anti-Patterns

- Delegating because a task feels boring but is narrow.
- Asking multiple agents the same vague question and averaging their answers.
- Letting a subagent choose write scope without constraints.
- Reporting delegated results without checking cited artifacts.
- Using agents to bypass mandatory routing, security, citation, or verification
  gates.

## Related Skills

- `dev-scout` for read-only codebase exploration.
- `decide-review` and `critique-argument` for fresh-perspective review.
- `research-protocol` for literature/citation checks.
- `dev-verification` before trusting delegated completion claims.
