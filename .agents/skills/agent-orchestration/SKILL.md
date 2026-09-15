---
name: agent-orchestration
description: "Use for multi-agent delegation: spawning subagents, parallel codebase exploration, independent research/review tasks, prompt scoping, avoiding duplicate work, and verifying delegated results."
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

Stay local for a single known file, a small edit, a narrow symbol lookup, a
simple explainer, or any task where the delegation prompt would be longer than
doing the work. A deterministic script also beats fan-out: if one pass over the
inputs does the job, write and run it instead of spawning delegates to
hand-apply it.

The agent count follows the task's shape, and has a ceiling: two for a two-way
comparison, three or four for a survey, four to six when the question spans
domains. More than that is not more coverage; it is the same sources re-read
with citations that disagree, and an integration step the parent cannot do.

## Prompt Contract

Every delegated task states:

1. Goal and non-goals.
2. Exact scope: paths, files, repos, query terms, or artifacts.
3. Whether the subagent may edit files. Default: read-only.
4. Required output shape: findings, file:line evidence, risks, and next
   action. State it as a contract on the final message — the last message IS
   the result, so name its exact shape (fields; a small JSON shape when the
   result is consumed mechanically) and treat a final message that does not
   match as an incomplete task, not a result to salvage. When the findings are
   bulk, they go to a file and the final message is the path plus a one-line
   summary: the parent reads the file, and the summary is what survives a
   later compaction.
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
11. For search-shaped work: triage a result list by title before fetching any
    item, and track each assigned question as done, blocked, or needs
    follow-up, so a question that found nothing is reported rather than
    silently dropped.

## Coordination Rules

- Split by independent scope, not by arbitrary steps that depend on each other.
- When fanning out over ONE large artifact — a manuscript, a proof, a long log —
  extract the shared evidence once in the parent and hand each agent its own item
  plus only that item's slice. N agents each re-reading the same source pays N
  times for one copy of the content, and their citations then disagree, because
  each re-derived its own line and page numbers. This is the inverse of the
  bulk-payload rule above: route bulk *in* to a subagent, but never route the
  same bulk to several.
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

## Phase Boundaries

At the end of a thread — a literature sweep done and implementation next, a
run launched and now awaited, a result read and a write-up due — five moves
are available. Take them in this order; the first that fits wins.

1. **Continue.** The only move that costs nothing and loses nothing. Ruled out
   only when the next thread does not need what is in the window, or the window
   is nearly full.
2. **Clear** and start fresh. Right when the next thread is independent, or
   when the thread's state lives outside the window: a launched cluster job
   holds its own state in the job and its artifacts, which makes a clear cheap.
3. **Handoff** (`session-handoff`). When the next thread is a later session,
   or another agent.
4. **Subagent.** When the next thread is bulk reading or independent search
   whose payload should never enter this window (When to Delegate).
5. **Compact.** Last, not first. Every move except continue converts the
   session as it happened into a summary of it; compaction is the move where
   the summary is written by no one in particular, and the standard failure is
   a session confidently wrong about a decision the summary flattened. The
   reasoning behind an experimental design is exactly what flattens.

## Anti-Patterns

- Using agents to bypass mandatory routing, security, citation, or verification
  gates.

## Related Skills

- `dev-scout` for read-only codebase exploration.
- `critique-argument` for fresh-perspective review.
- `research-protocol` for literature/citation checks.
- `dev-verification` before trusting delegated completion claims.
