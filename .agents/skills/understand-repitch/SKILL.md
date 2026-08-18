---
name: understand-repitch
description: Load the moment the user signals the last message or current state did not land — "wait, what?", "I'm lost", "hold on", "I don't follow", "re-explain", "say that again" — or asks for a re-pitch. Stop and re-explain at project altitude before doing anything else. For rebuilding their grasp of the whole project, use understand-project.
---

# Skill: Understand Repitch

## Purpose

Cheap mid-flow reorientation: the user lost the thread of the current moment,
not the whole project. Re-pitch, don't proceed. This is the micro end of the
comprehension ladder — `understand-repitch` → `understand-project` → `understand-codebase`.

## Rules

- Stop forward work immediately; the re-pitch is the whole next message.
- Re-pitch at project altitude: one or two sentences of context — what we are
  doing and why it serves the project goal — then restate the thing that did
  not land.
- Plain language: short sentences, one idea per sentence, no jargon the
  project's own docs don't use. Use `CONTEXT.md` vocabulary where it exists;
  never chat-local shorthand or invented labels.
- Ground statements in artifacts (file, PLAN.md section, commit, log entry),
  not conversation memory.
- End with at most one check: which part is still unclear, or a one-line
  confirmation of the next action.
- The interruption is not disagreement or a change request; nothing is
  decided or reverted until the user says so.

## Routing

- The user has lost the whole project thread, not just this message →
  `understand-project`.
- The confusion traces to an overloaded term → resolve and record it per
  `plan-interview`'s glossary rule.
- The re-pitch exposes that the work has drifted from the agreed plan → say
  so and stop; route to `plan-interview` or `research-plan` before resuming.

## Anti-Patterns

- Re-sending the same explanation louder or longer.
- Continuing the task in the same message as the re-pitch.
- Treating "wait, what?" as approval to simplify the plan itself.
