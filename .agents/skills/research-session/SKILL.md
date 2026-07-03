---
name: research-session
description: Use for research session orientation and idea triage: catch me up, what should I work on, research briefing, active/stale threads, evaluate a research idea or hunch, should we try X, pursue/refine/park/kill.
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
3. Critique assumptions, threats, baselines, and failure modes.
4. Propose cheap evidence: lit check, toy experiment, data audit, or proof sketch.
5. Decide: pursue, refine, park, or kill — score via `decide-priority` criteria; this skill owns only the research-specific tests above.

## Related Skills

- `research-protocol` before any citation/literature content this produces.
- `decide-priority` for scoring pursue/refine/park/kill.
- `research-lit-search` / `research-paper` / `research-run` as routed targets.
- `plan-day` for day-level planning rather than research-thread orientation.
