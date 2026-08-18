---
name: learn-topic
description: Use to learn a new topic or concept over a durable, multi-session workspace: build lessons, cheat-sheet reference docs, and a learning record tied to a stated goal. Use when the user wants to learn, study, get taught, ramp up on, or build understanding of a subject.
---

# Skill: Learn Topic

## Purpose

Turn a learning goal into a durable, revisitable workspace instead of a one-shot explanation: lessons that teach one thing at a time, reference docs built for later lookup, and a record of what's already understood.

## Workspace

Treat the current directory as the workspace for this topic. Create files lazily, on first use.

**First check the directory is not an existing project.** If it contains a `PLAN.md`, `pyproject.toml`, `.git`, or a populated `src/`, stop and ask for a dedicated learning directory. `CONTEXT.md` and `LOG.md` are owned names there — the project glossary (`plan-interview`) and the prepend-only run log (`context-project-docs`) — and writing lessons into them corrupts both.

- `MISSION.md` — why the user wants to learn this. Grounds every lesson.
- `CONTEXT.md` — one growing learning reference/cheat-sheet, sectioned by term or concept. This is scoped to the learning workspace; repo-root project terminology remains owned by `plan-interview`.
- `LOG.md` — one running, prepend-only log of non-obvious insights or corrected misconceptions, dated newest first. Drives the next lesson's difficulty; add a correction entry later if an old entry turns out wrong.
- `lessons/NNNN-<slug>.html` — one self-contained, single-sitting lesson, numbered from `0001`. The primary deliverable.
- `assets/` — shared stylesheet/components reused across lessons.

## Rules

- Ground every lesson in `MISSION.md`. Missing or stale mission → interview the user on why before teaching anything (route to `plan-interview` if it needs more than one question); confirm before changing an existing mission.
- Never teach from parametric knowledge alone — find and cite a high-quality external source per lesson before writing it.
- Target the zone of proximal development: read `LOG.md` first, then teach the most relevant next thing that's challenging but not overwhelming.
- Knowledge (new facts) wants minimum difficulty — teach only what the lesson's skill requires. Skill practice wants effortful retrieval (recall, spacing, interleaving) — that difficulty is the point, not a flaw.
- Reuse `assets/` components before writing new ones; promote a new one to `assets/` the moment a second lesson would duplicate it.
- Keep `CONTEXT.md` pure compressed reference — no narrative, five-second lookup, devoid of implementation/lesson-plan detail.
- When the user needs real-world calibration a lesson can't give (practice, critique, current field norms), point them at a high-reputation community rather than guessing — drop it if they don't want one.
- Provide the lesson file path after writing it; open it only when the environment supports opening files.

## Workflow

1. Check `MISSION.md`. If missing, stale, or the topic doesn't fit it, interview why the user wants to learn this and write/update it.
2. Read `LOG.md` to place the next lesson in the zone of proximal development.
3. Find and cite a primary source for the lesson's content.
4. Write one `lessons/NNNN-<slug>.html`: tightly scoped, single sitting, cites its source, links related lessons and `CONTEXT.md` sections, ends with a prompt to ask follow-up questions.
5. If the lesson produced durable reference material, append/update the matching section of `CONTEXT.md`.
6. After the user engages with the lesson, append a dated `LOG.md` entry for anything non-obvious learned or corrected.

## Output Shape

- Lesson file path (opened for the user).
- `CONTEXT.md` sections touched.
- `LOG.md` entry, if any.
- Suggested next lesson.

## Related Skills

- `plan-interview` when the learning goal itself needs interviewing.
- `context-org` when source material comes from notes or protected stores.
- `research-protocol` when the topic is academic-paper-shaped — route citations through it instead of ad hoc sourcing.
- `understand-project` / `understand-codebase` when the subject is a specific project or
  codebase rather than a topic — those read the artifact itself as ground truth,
  where this skill requires an external source per lesson.
