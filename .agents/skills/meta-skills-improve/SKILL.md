---
name: meta-skills-improve
description: "Use after long agent sessions or repeated workflow friction to improve personal agent skills: extract reusable procedures, update routing, clarify rules, remove contradictions, and draft safe changes for ~/.agents/skills."
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

## Placement decides whether a rule survives

Where a rule lives predicts its lifespan better than how well it is written. A
rule embedded in a document about something else dies when that something else
is retired, however good the rule was; the same rule in a file of its own, that
loads on its own trigger, outlives the thing it was written for and accumulates
detail. Two consequences:

- Do not attach a general rule to a specific roster, tool or workflow. Prose
  that names the members of a set becomes wrong the moment the set changes,
  and it takes the good content with it.
- A rule that must apply to EVERY message cannot live behind a trigger. Style
  and register rules are the clearest case: gated on a description, they fire
  only when someone asks for prose editing and never on the ordinary messages
  where the register actually slips. Those belong in the always-loaded layer.

## Reachability: which channel can carry a rule at all

Before rewriting a rule that is not being followed, decide whether any rewrite
could help. Three channels exist and they are not interchangeable:

- **A gate** fires on an event the agent EMITS — a command, a write, a fetch.
  Deterministic, and the strongest channel available.
- **Injection** puts the text in front of the agent at the moment of a specific
  event, without requiring it to decide to load anything. Where it applies it
  can beat a gate, because it delivers instead of denying-and-forcing-a-retry.
- **Prose** relies on the agent noticing that a rule applies.

The limit worth knowing: every gate keys on something the agent emits, so a
behaviour whose trigger is the absence of an action — asking before acting,
verifying before starting, orienting before working — has no event of its own.
Before calling it ungateable, look for an adjacent emitted event (the command
that creates the state, the write that follows the decision); only when none
exists is prose the ceiling.

Separate that from the description question, which the Firing Audit answers
below and which this does not overrule. A description can still be wrong for an
absence-triggered behaviour, and fixing it still helps: it decides whether the
skill is in front of the agent at all. What no rewording buys is DETERMINISM —
the rule will still be followed sometimes and not others. So reword the
description once if it is genuinely misleading, then stop and say the ceiling
has been reached, rather than rewriting the body a third time expecting
compliance. The honest alternatives are a channel that does not depend on the
agent's judgement, or accepting partial compliance and saying so.

The dual of this is already in Rules: if only a hook could enforce a lesson,
record that and stop.

## Firing Audit

The highest-value input to this skill, and the one reading can never supply.
Run it before a round of edits, and again weeks later to see whether the edits
changed anything.

**Run `audit.sh` in this skill's own directory** — do not retype its queries from
memory or summarise them. It reports counts per skill, never-fired, fired-but-no-
directory, gate compliance, and where in the session each skill fires. It takes
the harness's session-transcript directory as its first argument and the
deployed skills directory as its second; pass both when auditing a harness
other than the one its defaults name, and check that the load marker at the
top of the file matches how that harness records a skill load.

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

## Two Budgets

Every skill is paid for twice, from different accounts, and an edit that is
cheap on one can be expensive on the other.

- **Context load** is what the agent pays on every turn: the descriptions of
  all skills ride in every request, whether or not a skill fires, and the
  always-loaded instruction layer rides with them. A description is the
  expensive part of a skill; a body costs only the turns it is open.
- **Cognitive load** is what the human pays: what they must remember to type,
  which name to use, which file to open. Model-invoked skills trade context
  load for cognitive load; that trade is deliberate here.

Prune descriptions against context load and bodies against the no-op test.
Where a body grows, disclose progressively: an in-file step for what every
path needs, an in-file reference for what most paths need, and a sibling file
behind a pointer for what only one branch reaches — branching is the test for
which rung a piece of content belongs on.

A completion criterion has two independent properties. **Clarity**: can the
agent tell done from not-done? A vague bound ("cover the main cases") invites
early completion. **Demand**: how much does meeting it require? "Every
modified model accounted for" forces legwork that "produce a change list"
does not. Check both when a skill's step names an end state.

## Workflow

1. Capture the reusable lesson from the session.
2. Separate general workflow from one-off project context.
3. Inspect relevant skills in `~/.agents/skills`.
4. Choose the narrowest existing skill that fits, or justify a new skill.
5. Check invocation, distinct triggers, completion criteria (Two Budgets below), duplication, no-op advice, routing conflicts, related-skill overlap, and sediment in the target skill's existing content.
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
