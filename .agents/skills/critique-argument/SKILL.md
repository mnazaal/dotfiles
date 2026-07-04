---
name: critique-argument
description: Use to adversarially stress-test a claim, research idea, plan, design rationale, or piece of argumentative writing for weaknesses. Use when asked to critique, red-team, push back on, find holes in, or steelman/strawman-check an argument, before the user commits time to it.
---

# Skill: Critique Argument

## Purpose

Find the strongest reasons an argument might be wrong or weak, before the
user invests time acting on it. Distinct from `plan-interview` (resolves
ambiguity by asking questions — the argument isn't fully formed yet) and
`decide-priority` (chooses among already-known options) — this skill assumes
a claim has been stated and stress-tests it.

## Rules

- Criticize the argument, not the arguer.
- Separate what is claimed from what the evidence actually supports.
- Every criticism must be falsifiable or point to a concrete missing
  check — not vague ("needs more rigor").
- State the strongest case *for* the argument, as its proponent would state
  it, before the strongest case against — an asymmetric critique is not
  trustworthy.
- Do not default to a soft verdict (Refine) when a hard one (Kill/Reject) is
  more honest.
- Do not fabricate counter-evidence, competing work, or citations; flag
  uncertainty instead of inventing it. Follow `research-protocol` if the
  critique depends on verifying prior work.

## Process

1. Distill the argument into one sentence (the claim/nugget).
2. Identify what would have to be true for the claim to hold, and what
   evidence exists for each part now.
3. Find the single strongest objection — the one a sharp, motivated critic
   would raise first.
4. Find the strongest case for the argument, stated as strongly as its
   proponent would.
5. Check calibration: does the stated confidence match the evidence?
6. Give a verdict fit to the object: Pursue/Refine/Kill for ideas and plans;
   Accept/Revise/Reject for claims and prose.
7. Name the one next question or check that would most reduce uncertainty.

## Output

- Claim / Nugget
- Strongest Argument For
- Strongest Argument Against
- Calibration Check
- Verdict
- One Next Question or Check

## Constraints

- Critique only: do not rewrite the user's argument or prose for them, and
  do not edit files or run shell commands as part of the critique itself.
- Do not invent related work, competitors, or citations.

## Related Skills

- `plan-interview` when the issue is unresolved ambiguity, not weakness in a
  stated argument.
- `research-protocol` when novelty/competitive-landscape claims need
  verified paper search.
- `decide-priority` once the verdict is in and the user is choosing between
  options.
- `research-session` Idea Triage for the research-project framing of this
  same critique.
