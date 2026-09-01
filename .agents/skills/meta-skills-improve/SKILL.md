---
name: meta-skills-improve
description: Use after long agent sessions or repeated workflow friction to improve personal agent skills: extract reusable procedures, update routing, clarify rules, remove contradictions, and draft safe changes for ~/.agents/skills.
---

# Skill: Meta Skills Improve

## Purpose

Turn lessons from real agent sessions into better personal skills.

Use when a session reveals a reusable workflow, repeated mistake, missing routing rule, unclear boundary, weak verification step, or behavior that should be captured in `~/.agents/skills`.

## Rules

- Prefer updating an existing skill over creating a new one.
- Create a new skill only for a distinct trigger and repeatable workflow.
- Keep skills short, operational, and action-oriented.
- Prefer sharper gates over longer prose.
- Test each new line with the no-op test: does it change behavior versus the model's default? If not, cut the whole sentence, not just trim it.
- Prompt the positive: steering by prohibition drags the forbidden behavior into context. State the behavior to do; reserve "never X" for hard safety gates.
- When collapsing duplication, prefer one strong term reused in body and description (a leading word) over deleting the extra copy and leaving the idea unanchored.
- Whenever editing a skill, scan its existing body for sediment — content that no longer reflects current behavior — and propose removing it alongside the new addition.
- Audit firing, not just content — see Firing Audit below. Reading a skill tells you whether it is good; only the transcripts tell you whether it runs.
- Fit additions into a skill's existing headings; add a new heading only for a genuinely distinct concern.
- Do not encode one-off session details.
- Do not duplicate global instructions unless the skill needs a local reminder.
- Keep skills harness-agnostic: `~/.agents/skills` is shared across harnesses,
  so anything naming one harness's tools, hooks, config files, or invocation
  flags belongs in that harness's own configuration, with at most a
  harness-neutral pointer in the skill.
- Do not conflict with higher-priority system, developer, or global instructions.
- Preserve safety, verification, citation, read/write, and protected-storage policies.
- Ask before editing skill files unless the user explicitly requested edits.
- Route a lesson only to a skill the session actually loaded. Text added to a skill that never opened changes nothing.
- A skill that should have fired but did not is a description fix, not a body addition. Label every proposed change: description, body, or neither.
- Read the target section before accepting a body edit. If the guidance is already there and was skipped past, the fix is placement or wording, never a second copy.
- If only a hook or script could enforce a lesson, record that and stop: do not write prose that will be ignored, and do not build the mechanism unasked.
- Codify a preference only after seeing it twice. Once, and contradicted once, is noise.

## Firing Audit

The highest-value input to this skill, and the one reading can never supply.
Run it before a round of edits, and again weeks later to see whether the edits
changed anything.

**Run `audit.sh` in this skill's own directory** — do not retype its queries from
memory or summarise them. It reports counts per skill, never-fired, fired-but-no-
directory, gate compliance, and where in the session each skill fires. It takes
the harness's session-transcript directory as its first argument (default suits
the current one) and assumes each load appears as `"skill":"<name>"`; that marker
is the only harness-specific assumption and is a variable at the top of the file.

What the sections are for:

- **Counts, never-fired, orphans.** Weight by age before concluding — a skill
  added last week cannot have fired yet. Names fired with no directory are
  built-ins or renamed/removed skills; check for dangling routing references.
- **Gate compliance.** For a skill that should fire on an event, the share of
  sessions containing that event that also loaded it. A rule declared mandatory
  but sitting at low compliance needs a hook, not more prose.
- **Where in the session it fired.** Early is resume-shaped, late is write-shaped.
  This is how a two-directional skill that only works in one direction shows up,
  and it shows up nowhere else.

Read the output as three different diagnoses, not one:

1. **Never fires** — wrong trigger words, or the skill is genuinely unwanted.
   Only this one is fixed by editing a description. The description is a
   pointer, and its wording — not its target — decides firing: event-shaped
   triggers ("when committing", "before any clarifying question") fire, while
   judgment-shaped ones ("when work needs structured questioning") require the
   model to admit a state it defaults out of. A must-have behavior behind a
   weakly worded pointer is a variance bug, not a content problem.
2. **Fires, but too late to matter** — the trigger describes the aftermath
   rather than the moment the advice would have changed something.
3. **Fires, but the result is not what the user wanted** — the trigger is fine
   and the content is wrong. Counts alone will never reveal this; it surfaces
   when the user complains despite healthy usage.

A skill at zero after real exposure is evidence to cut, not a prompt to
advertise it harder (`dev-ponytail`). Retire it and fold anything durable into
a skill that does fire.

## Blinded Comparison

The Firing Audit says whether a skill runs. This says whether an edit is an
improvement. Run it before promoting a change you cannot judge by reading.

- Run both variants blind. An agent that knows it is being evaluated behaves
  differently.
- No eval, test, judge, rubric, score, compare, benchmark, or candidate wording
  in any path, file, or prompt the variant sees. Use project-shaped directory
  names.
- The task prompt reads as an organic request: state the goal, not the meta.
- Never ask the variant which skills or rules it applied; that question inflates
  citation behavior. Grade from the artifact it produced and the files it
  actually opened.
- Score both variants in ONE judging pass on one scale. Two passes drift in
  calibration.
- Read both outputs yourself before accepting a verdict. Disagreement with the
  judge means the criteria were ambiguous, not that the judge was wrong.
- Use content the variant has not seen before; a familiar task measures recall,
  not the edit.

## Workflow

1. Capture the reusable lesson from the session.
2. Separate general workflow from one-off project context.
3. Inspect relevant skills in `~/.agents/skills`.
4. Choose the narrowest existing skill that fits, or justify a new skill.
5. Check invocation, distinct triggers, completion criteria, duplication, no-op advice, routing conflicts, related-skill overlap, and sediment in the target skill's existing content.
6. Draft minimal markdown changes in the existing skill style.
7. Present affected files, proposed patch, risks, and recommendation.
8. Apply only with explicit user approval.

## Output Shape

- Session lesson.
- Target skill changes.
- Proposed patch.
- Routing / conflict check.
- Recommendation: apply, revise, or skip.

## New Skill Criteria

Create a new skill only if:

- It has a clear trigger.
- It has a repeatable workflow.
- It does not mostly duplicate an existing skill.
- It would be used often enough to matter.
- It can route cleanly to related skills.
- Keep every skill callable and auto-routable in the active harness.

## Anti-Patterns

- Adding generic advice like “be careful” or “think deeply.”
- Encoding current project facts into personal skills.
- Editing dotfiles without explicit permission.

## Related Skills

- `dev-scout` for read-only exploration before proposing changes.
- `dev-verification` before claiming skill updates are correct.
- `debug-root-cause` when repeated agent failure needs diagnosis.
- `decide-priority` when choosing which skill improvements matter.
