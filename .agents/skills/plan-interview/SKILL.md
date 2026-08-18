---
name: plan-interview
description: Load BEFORE asking the user any clarifying question about scope, approach, requirements, or design — including before every structured question tool call (e.g. AskUserQuestion) on a plan, implementation approach, research direction, or workflow change; also when the user asks to be interviewed or asked one question at a time. Use critique-argument for adversarial stress-tests of a formed claim.
---

# Skill: Plan Interview

## Purpose

Clarify ambiguous work before execution by interviewing the user one decision at a time.

Use when unclear scope, assumptions, dependencies, risks, acceptance criteria, or sequencing would make immediate action wasteful. If the workspace can answer the question, inspect instead of interviewing. If the options are already known and only ranking remains, route to `decide-priority`.

## Rules

- Work the open decisions as a tree and interview in rounds: the frontier is
  every question whose prerequisites are already settled. Ask the whole
  frontier in one round — numbered, each with a recommended/default answer —
  then wait for the answers. A question whose answer depends on another
  question still open this round belongs to a later round, not this one.
- If the user asks for one question at a time, honor that pacing instead.
- A harness's structured question tool (e.g. AskUserQuestion) is a delivery
  mechanism, not a substitute for this skill: one round per call, batching
  only independent questions, each with its recommended default marked as
  such; an oversized round splits across calls, dependent questions never do.
- Facts are yours, decisions are the user's: when a frontier question waits on
  a fact from the environment, inspect or dispatch a subagent without blocking
  the round — only questions downstream of the missing fact wait.
- If a question times out (user away), record your recommendation as the
  provisional answer, post the remaining question queue with recommendations,
  and stop; confirm provisional answers when the user returns.
- If the answer can be discovered by inspecting files, code, docs, logs, or prior context, inspect instead of asking.
- Resolve blocking assumptions before implementation details.
- Prefer concrete decisions over open-ended brainstorming.
- If the user reaches for a vague or overloaded term (e.g. "account" when
  Customer vs. User is ambiguous), stop and ask which precise meaning they
  intend before proceeding. Check for an existing CONTEXT.md first — defer to
  established terminology over inventing new terms.
- In ML contexts these overloaded terms trip the same rule proactively —
  they read fine in both technical and colloquial senses, which is exactly
  how they slip through: likelihood, inference, bias, regression, validation,
  sample, feature, parameter, prior, model, online, epoch. E.g. "inference":
  posterior inference vs. a deployed model's forward pass.
- When a term is resolved this way, record it in `CONTEXT.md` at the repo
  root (create lazily, on first resolved term): bolded term, a 1-2 sentence
  definition, and an `_Avoid_:` line for rejected synonyms. Keep it a pure
  glossary — no implementation details.
- Stop when the remaining uncertainty is low enough to produce a plan, next action, or handoff.

## Workflow

1. State the object being interviewed: plan, design, change, research direction, or decision.
2. Map the open decisions as a tree and find the frontier, highest-risk first.
3. Ask the frontier as one round of numbered questions, each with a
   recommended/default answer.
4. Wait for the user's answers.
5. Recompute the tree — settled answers unblock dependent questions — and ask
   the next round, until scope, constraints, risks, dependencies, and success
   criteria are clear.
6. For each resolved decision, check whether it is hard to reverse, would
   surprise a future reader, and reflects a real trade-off between
   alternatives. If all three hold, offer to record it in the project's
   decision log — `research-plan` owns its shape and home (a `## Decision log`
   section in `PLAN.md` by default, `docs/adr/` where that convention already
   exists). Never inline it into a plan section instead.
7. Summarize decisions made, unresolved risks, and the recommended next action.

## Routing

- Use `dev-scout` when repository inspection can answer a question.
- Use `decide-priority` when choosing among known options.
- Use `dev-ponytail` when the plan may be over-engineered.
- Use `debug-root-cause` when the plan is actually an unclear bug fix.
- Use `research-protocol` before academic-paper, literature, citation, related-work, bibliography, author-lookup, or field-survey content.
- Use `research-plan` for the decision log's shape and home, and for persisting a settled direction into `PLAN.md`.
- Use `meta-skills-improve` when the interview reveals a reusable workflow or skill improvement.

## Anti-Patterns

- Asking dependent questions in the same round.
- Serializing independent questions into separate round-trips.
- Asking the user for facts the workspace can answer.
- Continuing to interrogate after the next action is clear.
- Turning the interview into implementation.
- Ranking options without explicit criteria; route that to `decide-priority`.
