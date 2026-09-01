---
name: session-handoff
description: Use for both ends of a work session. Ending — "continue next session", "write up a handoff", "write everything down" — records done + next + dead ends and persists ephemeral state. Resuming — "continue from where we left off", "resume this project", "pick up where we left off" — reads the handoff artifact back and reconstructs state so a cold session resumes with zero re-derivation.
---

# Skill: Session Handoff

## Purpose

End a work session so a cold next session (or another agent) resumes with zero
re-derivation. Trigger: an explicit request — "continue next session", "write up
a handoff", "write everything down". A long session is not itself a trigger, and
neither is noticing that state lives only in chat/scratchpad; if that worries
you, say so and offer, rather than writing.

## Workflow

0. **Confirm you were asked.** The explicit handoff request is the authorization
   for this whole workflow — the block write AND the step-6 commit; without it
   you have neither, because writing or replacing this block mutates a
   standing document exactly as committing it would. If the existing block is
   merely *stale* because this session committed, branched, or closed an item
   it lists, correct those specific lines, say which and why, and stop; a
   stale line is a defect, but rewriting the block to fix one is not
   maintenance and destroys a record the user did not ask you to touch.
1. Write the handoff into a delimited block at the TOP of `PLAN.md`, directly
   below the title — **replace the block, never append a second one.** A handoff
   is single-valued: there is exactly one current answer to "where am I", and
   every older one is superseded by definition. `git log -p PLAN.md` is the
   archive, so replacing loses nothing. Same shape as `research-map`'s README
   block (`context-project-docs`): generated, delimited, regenerated rather than
   hand-edited.

   ```markdown
   <!-- session-handoff:begin (2026-07-27) -->
   …state, entry point, next action…
   <!-- session-handoff:end -->
   ```

2. Keep it to state with no other home: current branch, uncommitted or unmerged
   work, experiments still running (cluster job IDs, background tasks), env
   quirks found this session, scratchpad artifacts promoted into the repo and
   where they landed, and the single **entry point** — which section to read
   first and what concrete action follows, in words, never chat-local shorthand.
   Three more things a cold reader cannot re-derive: corrections — where this
   session found PLAN.md's picture of reality stale (route the fix per step 3;
   the handoff names the correction so the next reader distrusts the right
   sections); deviations from the agreed plan, each attributed — user-directed
   or agent-decided; and exit criteria as runnable commands — the command(s)
   whose output confirms the state the handoff claims.
   It sits above the plan because a cold reader needs it first, and it stays
   short because everything durable lives below it.
3. Route durable content to its existing home rather than restating it: verdicts
   and load-bearing numbers → `LOG.md` (`research-run`); decisions, execution
   order, next actions → `PLAN.md` (`research-plan`); dead ends and what NOT to
   re-pursue → `PLAN.md` risks; unresolved review findings, each with its
   pending-review status and the file:line it was found at → `PLAN.md` risks
   (`dev-verification`). The handoff POINTS at these; it does not re-narrate
   them.
4. Enumerate the scratchpad and decide each item explicitly, keep or discard.
   It is session-scoped and usually gone next session, so anything not promoted
   is lost — and which artifacts the next session needs cannot be predicted,
   which is why this is a list rather than a judgement.
5. Cold-read check before finishing: re-read the block as if you had none of
   this session's context, and name what you would still have to re-derive. Fix
   those gaps. This step is explicit because the writer holds maximum context
   and is therefore the worst-placed reader to notice what is missing — that is
   precisely how a record ends up complete and unusable (`understand-project`).
6. Commit as the final act (`dev-git`). The handoff request itself authorizes
   this commit and is the staging instruction `dev-git` expects: it covers
   exactly the files this workflow wrote, routed, or promoted (steps 1–4),
   staged by name — dirty files it did not touch stay out, and a routed file
   already carrying unrelated edits gets `dev-git`'s split procedure so only
   this workflow's hunks land. The user's next act is closing the session,
   and a handoff left uncommitted forces them to send one more "yes, commit"
   message. Skip only if the user said not to commit, and then name the
   commit as pending. The block is written BEFORE its own commit lands, so it
   cannot claim a clean tree: describe the repo as it will be after that
   commit.
   Otherwise the next session's first act is discovering that the handoff
   misreported state.

## Resume (reverse direction)

Trigger: "continue from where we left off", "resume this project", "pick up".
Read what this skill writes BEFORE acting:

1. `PLAN.md`'s `session-handoff:begin/end` block — the entry point. Current by
   construction; no scanning, no deciding which copy is newest.
2. Only if it is absent (a project predating this layout): scan `LOG.md` for the
   newest SESSION HANDOFF block. It is NOT necessarily the first entry — runs
   logged afterwards prepend above it — so falling through to "read the newest
   `research-run` blocks" silently skips the handoff.
3. The rest of `PLAN.md`: execution order, open risks, decision log.
4. Verify live state before trusting any of it: `git branch --show-current`,
   uncommitted/unmerged work, and any experiments still running (cluster jobs,
   background tasks). If the handoff carries exit-criteria commands, run them —
   verification is then a paste, not a judgment call.
5. Reconstruct for the user, not just yourself: open with ≤3 lines of frame —
   what problem the project solves, the current thread, and where the next
   action sits in it — before the entry-point details. Resuming agent state
   without restating the frame starts the session with the user already lost.
6. Confirm the next action with the user, then route.

No handoff artifact / generic "catch me up" → `research-session` Session Start.
If the artifact reconstructs agent state but the user has lost their own grasp
of the work, that is `understand-project` — re-reading the handoff will not fix it.

## Anti-Patterns

- Load-bearing results left only in session-temporary storage (scratchpad, chat).
- A subagent's findings left in the main agent's context. Read-only reviewers
  write nothing, so their output is the most context-fragile artifact a session
  produces, and an unrepaired finding that vanishes reads as a clean review.
- A handoff that lists what was done but not what is next or what is a dead end.
- Appending a session summary to `LOG.md`. That is the run/result log; a
  single-valued record accumulating in a prepend-only log means every superseded
  copy is re-read forever, and the results it exists to hold get diluted.

## Related Skills

- `context-project-docs` for LOG/PLAN shape (the canonical surfaces).
- `research-run` for the per-result verdict blocks a session summary cites.
- `research-session` for generic orientation ("catch me up") when there is no
  handoff artifact to resume from.
- `understand-project` when resuming reveals the user no longer understands the work
  the handoff assumes — reconstructing agent state does not reconstruct theirs.
- `dev-git` for the commit.
