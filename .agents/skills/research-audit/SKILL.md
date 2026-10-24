---
name: research-audit
description: "Use for a complete, independent, first-principles review of a research project: audit the project, review it from scratch, is the problem well defined, is the gap real or already scooped, is the method correct, are the claims supported by the experiments, a periodic check before submission or after a long run of work."
---

# Skill: Research Audit

## Purpose

Judge whether a project's problem, gap, method and evidence hold up, as a
reviewer who has not lived inside it would. The other research skills each own
one leg; this one runs all four under one rule: the reviewer forms its own view
before reading the project's.

Retrospective comprehension for the user is `understand-project`; this skill
produces verdicts, not understanding.

## Rules

- Reconstruct before reading. The cold pass sees the problem statement, the
  data, and the target quantity — never PLAN.md framing, `claims.md`, the
  abstract, or LOG verdicts. A reviewer who reads the project's own account
  first audits that account's internal consistency, not the project.
- Run each leg in a fresh context with read-only access, handed the artifacts
  (code, derivations, results, manuscript) rather than the lead's conclusions
  (`agent-orchestration`). The lead merges; it does not pre-digest.
- A leg ends in a verdict — Accept, Revise, or Reject — with the single
  defect it turns on. A leg that reports "mostly fine" has not been run.
- Every finding names the file, line, result path, or paper it rests on.
  Separate what was checked from what was guessed, and list what was searched
  and not found.
- Write findings into the project's existing records (Output); the audit
  leaves no standing report file.

## Workflow

1. **Locate the inputs.** The problem statement in the narrowest form the
   project states it, the data, the claim spine (`claims.md`, else the
   paper's contributions), the last novelty-gate record and its cutoff date,
   and the date of the previous audit if one is logged.
2. **Cold reconstruction.** From the problem statement and data alone: what a
   solution must deliver, which assumptions make the problem well posed, the
   strongest fair baseline, and the experiment that would separate a real
   method from that baseline.
3. **Four legs, in parallel**, each given the cold reconstruction:
   - **Framing** — `research-session` Framing triad and stress-test, run
     against the reconstruction. Every place the project's framing diverges
     from it is either a justified choice (cite where it is justified) or a
     defect.
   - **Novelty** — `research-lit-search` Novelty gate, re-run as a delta from
     the recorded cutoff: same ingredient classes, new papers since, plus any
     ingredient the framing leg found the original gate never searched. No
     recorded cutoff means a full gate.
   - **Correctness** — re-derive the load-bearing result independently, then
     check the code against the derivation (`research-map` divergences,
     `code-review`). A divergence is a defect until the record justifies it.
   - **Evidence** — walk every `claims.md` line: open the `results/` artifact
     it points to, confirm its strength label and that the wording does not
     claim more than the design delivers, and run the `research-run`
     Checklist and the evaluation-validity review over the supporting runs.
     A line whose artifact is missing is `asserted`, whatever its label says.
4. **Merge.** Cross-leg contradictions are the highest-value findings — a
   claim the evidence leg accepts but the correctness leg breaks, a gap the
   novelty leg finds occupied.
5. **Verdict for the project**: the weakest leg decides it. Name the one
   check or experiment that would most change it.

## Output

- Per leg: verdict, the defect it turns on, evidence pointers, searched-and-empty.
- Project verdict and the one next check.
- Persist, with user/policy authorization:
  - claim defects → that claim's `## Known weaknesses` or `## Status` in `claims.md`;
  - label downgrades and the audit verdict itself, dated → `LOG.md`;
  - the novelty delta, with its new cutoff → the project's literature notes;
  - a framing or plan change → `research-plan`.

## Boundary

- One idea before anything is built → `research-session` Idea Triage.
- One claim to attack, not the whole project → `critique-argument`.
- Rebuilding the user's own grasp → `understand-project`.
- Prose quality of the manuscript → `research-manuscript-workflow` Prose and
  Narrative Review.
- A run that is wrong, not merely unsupported → `debug-ml-research`.

## Related Skills

- `agent-orchestration` for scoping each leg's prompt and verifying its return.
- `research-protocol` before the novelty leg makes any literature claim.
- `context-project-docs` for where findings persist.
