---
name: learn-project
description: Use to rebuild understanding of a research project from its own records: walk me through this project, I have lost the thread, explain what was done and why, what does this claim rest on, what is the generative model, why does this proof work, where does it break, help me defend this to a reviewer. Works on a project being run, joined, resumed after a gap, or reviewed. Retrospective comprehension, not choosing what to do next.
---

# Skill: Learn Project

## Purpose

Transfer a research project's state out of its records and into the user's head,
at the depth needed to defend it to a reviewer — and repair the records where
they failed to transfer.

The common case is a record that is complete and unusable: written incrementally,
never read end to end, no longer matching what anyone remembers. The job is not
to summarize it. A summary is what already exists and is not being read.

## Rules

- Discover the sources; do not assume a layout. Projects name things
  differently, and a skill that assumes one convention fails silently on the
  next project.
- Read the chronology newest-first, never end to end. A running log grows
  without bound; read recent entries in full and scan the rest by heading and
  date to build a timeline.
- Ground every statement in a file, a dated entry, or a commit, cited so the
  user can check it. Never explain the project from what was said earlier in the
  conversation.
- Treat publication source — LaTeX manuscripts, submitted PDFs — as read-only.
  `research-manuscript-workflow` may forbid editing it outright, and some hosts
  enforce that at the tool layer rather than by convention.
- A scaffolded-but-unauthored section is not evidence the work was not done.
  Prefer whichever source has content over whichever is canonical but empty.
- Diagnose before teaching. Ask what the user believes, then teach to the
  difference. Do not grade the answer or say whether it was right — use it only
  to locate the gap.
- One question at a time.
- Every gap has one of two causes: the user forgot, or the record is broken.
  Decide which. The second is the more valuable finding.
- Persist as repairs to the project's existing documents, never a new standing
  document. When the project is not the user's to write to, hand the defects
  back as findings instead.

## Orientation

Locate four things. Each has a usual home and several fallbacks; take the first
that has content.

1. **The claim spine** — what the project asserts. A claims or evidence ledger
   in the planning area; else the paper's abstract and contributions; else the
   plan document's decisions; else the README.
2. **Status** — the plan document, or the newest chronology entries.
3. **Chronology** — a prepend-only log, dated notes, commit history, issues and
   pull requests. Newest in full, older by heading only.
4. **Actual effort** — the shape of `git log --oneline`. Divergence between
   where commits land and what the plan says is being worked on is itself a
   finding.

Report ~15 lines: what the project is, the live claims, what is settled versus
open, and the current front. With no claim spine, derive candidates from status
plus the newest chronology, and record its absence as a defect.

**"What the project is" means the problem, not the documents** — what is
observed, what is unknown, what the target quantity is, what actions are
available. A document inventory is not orientation, and claim-scoped depth
entered before this lands is wasted.

## Claim-Scoped Depth

Depth is always scoped to one claim. Covering a whole project at
reviewer-defense depth in one pass produces the same unreadable mush this skill
exists to prevent. Let the user pick a claim, or propose the one that is most
load-bearing or least defended.

For that claim, follow the trail: its entry in the spine → the derivations it
cites → the code implementing it → the results supporting it.

Reviewer-defense depth means the user can answer all of:

- What is the generative model? What is random, what is observed, what is
  conditioned on, and which independences are assumed. Draw it if that is
  clearer than prose.
- Which assumption is load-bearing here, and what happens if it is dropped — not
  that the result fails, but what specifically goes wrong.
- What does each step of the argument buy? A step whose purpose cannot be named
  is either unnecessary or not yet understood.
- What is the regime of validity, and what breaks first outside it.
- What is a reviewer's first objection, and the answer.

Re-deriving a proof line by line is a deeper, separate request; do it for one
named result when asked, not by default.

## Notation

Derivations written months apart introduce their own symbols and drift.
Maintain a reconciled symbol table in the project's planning area, following the
host's working-note convention: symbol, meaning, where it is defined, and any
collision between sources. Keep it out of publication source — that copy is the
author's to write, mirroring the split an evidence ledger already uses.

## Defects to Record

Route each; do not fix silently.

- A claim whose stated evidence contradicts a newer chronology entry → stale
  spine, correct it.
- An assumption used in a derivation but absent from that claim's known
  weaknesses → add it.
- A dead end the user rediscovered in conversation because it was never written
  down → the chronology. This is the expensive one.
- A recorded decision with no rationale → `research-plan`.
- A result whose verdict was never taken → `research-run`.
- Symbol collisions across derivations → the symbol table.
- A settled claim whose manuscript section is still unauthored →
  `research-manuscript-workflow`.

## Boundary

- Retrospective comprehension only.
- "What should I work on", briefing, or idea triage → `research-session`.
- "Resume where we left off" with a handoff artifact → `session-handoff`.
- Attacking a claim the user already understands → `critique-argument`.
- A project with no record to transfer — an external paper and its release —
  → `research-paper` and `research-map`; there is nothing here to read.
- Understanding a codebase rather than a research record → `learn-codebase`.

## Anti-Patterns

- Producing a summary instead of a diagnosis.
- Reading the plan and log in full and exhausting context before the math.
- Quizzing on trivia rather than on what is expensive to be wrong about.
- Explaining the method from the conversation's own memory instead of the files.
- Treating an unauthored scaffold as evidence the work was not done.
- Writing `UNDERSTANDING.md`, `SUMMARY.md`, or a session recap doc.

## Related Skills

- `research-session` for choosing what to do next, once oriented.
- `session-handoff` when a handoff artifact exists to resume from.
- `context-project-docs` for the canonical documents this repairs.
- `research-run` for a result whose verdict is still open.
- `research-plan` for persisting a decision that turned out to be unowned.
- `critique-argument` for attacking a claim rather than understanding it.
- `research-paper` / `research-map` when the subject is an external paper and
  its released code rather than a project record.
- `learn-codebase` for the same loop aimed at code.
