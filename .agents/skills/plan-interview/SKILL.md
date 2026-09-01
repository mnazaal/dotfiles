---
name: plan-interview
description: Load BEFORE asking the user two or more clarifying questions, any single question that would change the scope, approach, or design of the work, or any question laying out options for the user to choose among — including before a structured question tool call, on a plan, implementation approach, research direction, or workflow change. A lone factual or confirmatory question does not need it. Also when the user asks to be interviewed or asked one question at a time. Use critique-argument for adversarial stress-tests of a formed claim.
---

# Skill: Plan Interview

## Purpose

Clarify ambiguous work before execution by interviewing the user one decision at a time.

Use when unclear scope, assumptions, dependencies, risks, acceptance criteria, or sequencing would make immediate action wasteful. If the workspace can answer the question, inspect instead of interviewing. If the options are already known and only ranking remains, route to `decide-priority`.

## Rules

- Work the open decisions as a tree and interview in rounds: the frontier is
  every question whose prerequisites are already settled. Ask the whole
  frontier in one round — numbered, each in the Question Shape below — then
  wait for the answers. A question whose answer depends on another question
  still open this round belongs to a later round, not this one.
- If the user asks for one question at a time, honor that pacing instead.
- When the harness has a structured question tool, deliver decision questions
  through it rather than as chat prose — one channel, one look. Chat is the
  fallback and keeps the same Question Shape.
- The structured question tool is a delivery mechanism, not a substitute for
  this skill: one round per call, batching only independent questions; an
  oversized round splits across calls, dependent questions never do.
- Facts are yours, decisions are the user's: when a frontier question waits on
  a fact from the environment, inspect or dispatch a subagent without blocking
  the round — only questions downstream of the missing fact wait.
- If a question times out (user away), record your recommendation as the
  provisional answer, post the remaining question queue with recommendations,
  and stop; confirm provisional answers when the user returns.
- If the answer can be discovered by inspecting files, code, docs, logs, or prior context, inspect instead of asking.
- Inspecting is the floor, not the ceiling. If the answer is a fact you could
  observe by RUNNING something — does this eval separate the arms, does the
  sampler mix, what shape comes out, how long is one epoch — it is not the
  user's to answer. Run the smallest throwaway probe in the scratchpad, then
  report the observation instead of the question. Ask only for preference or
  direction calls no probe can settle.
- Resolve blocking assumptions before implementation details.
- Prefer concrete decisions over open-ended brainstorming.
- If the user reaches for a vague or overloaded term (e.g. "account" when
  Customer vs. User is ambiguous), stop and ask which precise meaning they
  intend before proceeding. Check for an existing CONTEXT.md first — defer to
  established terminology over inventing new terms.
- Before coining or adopting a label, check it against the terms of art in
  the project's OWN field: a word that is merely descriptive elsewhere can
  already name a specific concept here (e.g. "instrument" in causal
  inference). Prefer the source literature's own word over a new umbrella
  term, and record the rejected candidate with its reason in `CONTEXT.md` so
  it is not reintroduced.
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

## Question Shape

Every decision question — anything beyond a lone factual check — is asked in
one fixed shape, in chat and in a structured question tool alike:

1. **The decision**, in one line: what is being chosen and what it blocks.
2. **The options**, as a short lettered list — a, b, c — each letter paired
   with a name so an answer can say "(b) the soft hook" unambiguously. Each
   option gets one line of what choosing it means, and its main pro and con.
   Include "other/neither" only when it is a real option.
3. **Recommendation last**: the option you would pick and the one or two
   reasons that decide it. A question you cannot attach a recommendation to is
   not ready to ask — inspect or probe first.

In a structured question tool, the options map onto the tool's option slots
(pro and con in each description) with the recommendation marked on its
option; in chat, this is the shape of each numbered question in a round.

## Workflow

1. State the object being interviewed: plan, design, change, research direction, or decision.
2. Map the open decisions as a tree and find the frontier, highest-risk first.
3. Ask the frontier as one round of numbered questions, each in the Question
   Shape above.
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

- Turning the interview into implementation.
- Ranking options without explicit criteria; route that to `decide-priority`.
