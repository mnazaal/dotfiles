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
- To protect the context budget, not only for parallelism or fresh perspective:
  route bulk payloads (full training logs, `sacct` dumps, long PDFs, whole-file
  reads) to a subagent and take back a summary.

Stay local for a single known file, a small edit, a narrow symbol lookup, or any
task where the delegation prompt would be longer than doing the work. A
deterministic script also beats fan-out: if one pass over the inputs does the
job, write and run it instead of spawning delegates to hand-apply it.

## Prompt Contract

Every delegated task states:

1. Goal and non-goals.
2. Exact scope: paths, files, repos, query terms, or artifacts.
3. Whether the subagent may edit files. Default: read-only.
4. Required output shape: findings, file:line evidence, risks, and next
   action. State it as a contract on the final message — the last message IS
   the result, so name its exact shape (fields; a small JSON shape when the
   result is consumed mechanically) and treat a final message that does not
   match as an incomplete task, not a result to salvage.
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
9. Timebox: a rough cap on the run, with the contract that on expiry the agent
   returns partial findings and stops rather than running on.
10. No resume-chaining. Directives decay across resumes, so re-issue a fresh
    agent with consolidated scope instead of resuming one whose brief changed.

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
- Adversarial signal comes from independent reviewers seeing the same artifact
  and the same brief, not from assigned personas. Do not hand out roles.
- Two reviewers raising a finding independently is the strong signal; a lone
  finding is worth reading at lower confidence. This is not averaging — the
  question and the artifact are fixed.
- Fix the acceptance criteria before reading any reviewer output. They are the
  adjudicator's tool, not the reviewers'.
- Report what you dismissed and why alongside what you acted on. A silently
  dropped objection to an experiment design is invisible to the user.
- Reviewers pad to fill a review: an all-nits return is evidence the artifact is
  fine, so say that instead of promoting one.
- Wide divergence across agents means the brief was under-specified — re-frame
  and re-ask rather than merging the spread. Factual disagreement still goes to
  the smallest direct check.
- When the object under review is an experiment design, its intent is in scope:
  whether it tests the claim is the reviewable question.

## Anti-Patterns

- Using agents to bypass mandatory routing, security, citation, or verification
  gates.

## Related Skills

- `dev-scout` for read-only codebase exploration.
- `critique-argument` for fresh-perspective review.
- `research-protocol` for literature/citation checks.
- `dev-verification` before trusting delegated completion claims.
