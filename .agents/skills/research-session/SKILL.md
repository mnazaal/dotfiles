---
name: research-session
description: Use for research session orientation, idea triage, and project framing: catch me up, what should I work on, research briefing, active/stale threads, evaluate a research idea or hunch, should we try X, pursue/refine/park/kill, frame the problem/setting/gap, what are we assuming, how does this scale, how is X parameterized.
---

# Skill: Research Session

## Session Start

Use when orienting at the start of research work ("catch me up", "what should I work on", "research session").

1. Capture focus, if user gave one.
2. Inspect available research state: active projects, recent notes, open tasks, recent papers, run artifacts, saved ideas.
3. Summarize current state and stale/blocked items.
4. Suggest 2-3 next actions with concrete routes.
5. Route based on user choice or strongest evidence.

Keep briefing under 20 lines. Skip missing state silently; do not invent continuity. Do not write notes unless user or host policy allows it.

```text
Research Briefing — <date/focus>
- Active: <top thread or none found>
- Recent: <last useful artifact or none found>
- Blocked/Stale: <items needing decision or none found>
- Suggested:
  1. <action> → <skill>
  2. <action> → <skill>
  3. Open: what is on your mind?
```

## Idea Triage

Use when evaluating a research idea, direction, or hunch ("should we try X", "is this worth pursuing").

- Start with conclusion-first test: what would the successful paper/claim say?
- Identify riskiest assumption and cheapest evidence first.
- Prefer concrete next experiment/search over broad speculation.
- Separate novelty, feasibility, payoff, and fit.

1. Restate idea and target contribution.
2. Generate plausible framings and alternatives.
3. Stress-test via `critique-argument` (assumptions, threats, baselines, failure modes); for a deep fresh-context pass, spawn the host's idea-critic agent.
4. Propose cheap evidence: lit check, toy experiment, data audit, or proof sketch.
5. Decide: pursue, refine, park, or kill — score via `decide-priority` criteria; this skill owns only the research-specific tests above.

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

Persist the result where it belongs (PLAN.md framing or a `notes/` working note),
not only in chat. Route a deep adversarial pass on any single claim to
`critique-argument`; persist framing + decisions to the plan via `research-plan`.

## Related Skills

- `research-protocol` before any citation/literature content this produces.
- `critique-argument` for the stress-test in idea triage (step 3) and framing.
- `research-plan` to persist a settled framing into PLAN.md.
- `decide-priority` for scoring pursue/refine/park/kill.
- `research-lit-search` / `research-paper` / `research-run` as routed targets.
- `plan-day` for day-level planning rather than research-thread orientation.
