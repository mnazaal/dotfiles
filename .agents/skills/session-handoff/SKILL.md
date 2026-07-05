---
name: session-handoff
description: Use when ending a work session for a clean handoff — "continue next session", "write up a handoff", "write everything down", or a long session whose state lives only in chat/scratchpad. Records done + next + dead ends and persists ephemeral state so a cold next session resumes with zero re-derivation.
---

# Skill: Session Handoff

## Purpose

End a work session so a cold next session (or another agent) resumes with zero
re-derivation. Trigger: "continue next session", "write up a handoff", or a long
session whose state lives only in chat/scratchpad.

## Workflow

1. LOG.md — append a session-summary entry: what was done, the verdicts, and an
   explicit **what NOT to re-pursue** (dead ends, pre-empted directions). Shape
   per `context-project-docs` / `research-run`.
2. PLAN.md — update status + the next-session decisions/actions.
3. Persist ephemeral state: move scratchpad scripts/results the next session
   needs into the repo (or durable store). Make the handoff **self-contained** —
   inline the key numbers so it survives even if the artifacts are lost.
4. Update cross-session memory (state, env quirks, what is now superseded).
5. Commit the durable changes (`dev-git`).
6. Name the single **entry-point**: which doc to read first next session.

## Anti-Patterns

- Load-bearing results left only in session-temporary storage (scratchpad, chat).
- A handoff that lists what was done but not what is next or what is a dead end.
- Re-narrating the same content across LOG + PLAN + memory — each has one role
  (past / next / cross-session state); point between them, do not duplicate.

## Related Skills

- `context-project-docs` for LOG/PLAN shape (the canonical surfaces).
- `research-run` for the per-result verdict blocks a session summary cites.
- `research-session` for the reverse direction (orienting INTO a session).
- `dev-git` for the commit.
