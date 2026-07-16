---
name: session-handoff
description: Use for both ends of a work session. Ending — "continue next session", "write up a handoff", "write everything down" — records done + next + dead ends and persists ephemeral state. Resuming — "continue from where we left off", "resume this project", "pick up where we left off" — reads the handoff artifact back and reconstructs state so a cold session resumes with zero re-derivation.
---

# Skill: Session Handoff

## Purpose

End a work session so a cold next session (or another agent) resumes with zero
re-derivation. Trigger: "continue next session", "write up a handoff", or a long
session whose state lives only in chat/scratchpad.

## Workflow

1. If the project uses the canonical `context-project-docs` layout, update
   `LOG.md` by prepending a session-summary entry in canonical LOG order: what was done, the verdicts, and an
   explicit **what NOT to re-pursue** (dead ends, pre-empted directions). Shape
   per `context-project-docs` / `research-run`. Otherwise ask for the approved
   durable handoff location.
2. If present and governed by the project-doc policy, update `PLAN.md` status +
   the next-session decisions/actions.
3. Persist ephemeral state: move scratchpad scripts/results the next session
   needs into the repo (or durable store). Make the handoff **self-contained** —
   inline the key numbers so it survives even if the artifacts are lost.
4. Record state, env quirks, and what is now superseded in the handoff block;
   do not rely on an undefined external memory surface.
5. Offer to commit the durable changes (`dev-git`); commit only with explicit
   user authorization.
6. Name the single **entry-point** and next action in words: which doc to read
   first next session, and what concrete action follows. Do not use chat-local
   shorthand.

## Resume (reverse direction)

Trigger: "continue from where we left off", "resume this project", "pick up".
Read what this skill writes BEFORE acting:

1. `LOG.md` first entry — a SESSION HANDOFF block is the entry point (arc,
   what-NOT-to-re-pursue, next actions); else read the newest `research-run` blocks.
2. PLAN.md status + next actions; handoff-recorded env quirks and superseded state.
3. Verify live state first: `git branch --show-current` + uncommitted/unmerged
   work, and any experiments still running (cluster jobs, background tasks).
4. Confirm the next action with the user, then route.

No handoff artifact / generic "catch me up" → `research-session` Session Start.

## Anti-Patterns

- Load-bearing results left only in session-temporary storage (scratchpad, chat).
- A handoff that lists what was done but not what is next or what is a dead end.
- Handoff entries that rely on invented labels from the chat, e.g. “continue
  with P1/T2”, instead of restating the concrete next action.
- Re-narrating the same content across LOG + PLAN + memory — each has one role
  (past / next / cross-session state); point between them, do not duplicate.

## Related Skills

- `context-project-docs` for LOG/PLAN shape (the canonical surfaces).
- `research-run` for the per-result verdict blocks a session summary cites.
- `research-session` for generic orientation ("catch me up") when there is no
  handoff artifact to resume from.
- `dev-git` for the commit.
