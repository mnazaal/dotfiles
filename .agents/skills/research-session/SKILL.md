---
name: research-session
description: Use for research session orientation, idea triage, and project framing: catch me up, what should I work on, research briefing, active/stale threads, evaluate a research idea or hunch, should we try X, pursue/refine/park/kill, frame the problem/setting/gap, what are we assuming, how does this scale, how is X parameterized.
---

# Skill: Research Session

## Session Start

Use when choosing or framing research work, not for writing the durable plan. If the user asks to persist decisions in `PLAN.md`, route to `research-plan`; if ambiguity blocks even framing the question, route to `plan-interview`. If the user wants to understand what was already done rather than pick what to do next ("walk me through this", "I've lost the thread"), route to `understand-project` — this briefing is deliberately shallow and will not get them there.

1. Capture focus, if user gave one.
2. Inspect available research state: active projects, recent notes, open tasks, recent papers, run artifacts, saved ideas.
3. Summarize current state and stale/blocked items. If a research-code repo's
   README lacks a `research-map` overview block, or the stamp on that block or
   on `notes/main.html` trails HEAD by many commits, name that as stale state
   and offer `research-map`.
4. Suggest 2-3 next actions with concrete routes.
5. Route based on user choice or strongest evidence.

Keep briefing under 20 lines. Skip missing state silently; do not invent continuity. Do not write notes unless user or host policy allows it.
Do not assign persistent codes to threads or suggestions. If numbering a list,
refer back by descriptive name, not by number alone.

```text
Research Briefing — <date/focus>
- Active: <top thread or none found>
- Recent: <last useful artifact or none found>
- Blocked/Stale: <items needing decision or none found>
- Suggested:
  1. <descriptive action> → <skill>
  2. <descriptive action> → <skill>
  3. Open: what is on your mind?
```

## Idea Triage

Use when evaluating a research idea, direction, or hunch ("should we try X", "is this worth pursuing").

- Start with conclusion-first test: what would the successful paper/claim say?
- Identify riskiest assumption and cheapest evidence first.
- Prefer concrete next experiment/search over broad speculation.
- Separate novelty, feasibility, payoff, and fit.

1. Restate idea and target contribution.
2. Match it against the project's recorded dead ends and ruled-out directions
   (PLAN.md risks and decision log) by concept, not keyword — "night theme"
   matches a dark-mode rejection. On a hit, surface the recorded reason and
   ask whether it still holds before any fresh evaluation.
3. Generate plausible framings and alternatives before scoring any of them:
   alternative framings, cross-field connections, extensions, the high-risk
   variant, and the counter-arguments worth testing. Produce the whole set
   first — evaluating each candidate as it appears collapses the range. When
   the current framing is likely to anchor generation, use
   `agent-orchestration` to spawn a read-only subagent for an unanchored pass.
4. Stress-test via `critique-argument` (assumptions, threats, baselines, failure modes); for a deep fresh-context pass, use `agent-orchestration` to spawn a constrained critique subagent.
5. Propose cheap evidence: lit check, toy experiment, data audit, or proof sketch.
6. Decide: pursue, refine, park, or kill — score via `decide-priority` criteria; this skill owns only the research-specific tests above. Name the lens the
   decision actually turns on — triage, comparative advantage, field timing,
   opportunity cost, or scooping risk — and say which evidence would flip it.

## Framing

Use when asked to frame a project or answer a foundational question about it
("what's the problem/setting", "what are we assuming", "how does this scale",
"how is X actually parameterized", "what's the gap"). Elevate to the framing
triad and pressure-test it — do not just answer the surface question.

State the triad, grounded in the project's own docs (PLAN/notes), not memory:

1. Problem + setting: what is being learned, from what signal, what counts as a
   solution, and the assumptions that make it well-posed.
2. Gap: which neighboring approaches exist and which leg each is missing.
3. Approach: how this work supplies the missing leg; name the single most
   load-bearing / least-scooped claim.

Then stress-test the foundations unprompted, giving the honest answer over the
flattering one:

- Mechanism: what the core object/channel *is* (its exact definition), not a metaphor.
- Hidden assumptions: does a convenience (a linear/Gaussian instance, a fixed
  hyperparameter) leak into the claim? State assumption-lean vs assumption-free.
- Scaling: which step is a convenience of the small/exact regime vs load-bearing;
  what breaks first and what error it introduces — not just "it's expensive".
- Parameterization: the one conduit by which structure/information enters the
  model, and where that factorization breaks.

Offer to persist the result where it belongs (PLAN.md framing or a `notes/`
working note) when user/policy allows; otherwise keep it in chat. Route a deep
adversarial pass on any single claim to `critique-argument`; persist settled
framing + decisions to the plan via `research-plan`.

## Related Skills

- `plan-day` for day-level planning rather than research-thread orientation.

- `research-protocol` before any citation/literature content this produces.
- `critique-argument` for the stress-test in idea triage (step 3) and framing.
- `research-plan` to persist a settled framing into PLAN.md.
- `decide-priority` for scoring pursue/refine/park/kill.
- `research-lit-search` / `research-paper` / `research-run` as routed targets.
- `understand-project` when the user needs to rebuild their own understanding of the
  project, including its math, rather than choose the next action.
