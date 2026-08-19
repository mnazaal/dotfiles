---
name: plan-day
description: Use for good morning, start my day, plan my day, daily briefing, or what should I do next today using Org agenda and Emacs TODO context.
---

# Skill: Plan Day

## Purpose

Start the day by turning the Org store into a small, realistic plan.

Use when the user wants a morning brief, daily startup, daily plan, or next-action recommendation for today.

## Sources

Read `~/org/agenda/` directly. The Org agenda is a **date view**: it lists only
what carries `SCHEDULED` or `DEADLINE`, so most open items never appear in it.
Planning from the agenda alone reproduces that blind spot.

| file | what it is | how to use it |
|---|---|---|
| `primary-gcal.org`, `aalto-outlook.org` | generated calendar exports, refreshed continuously | today's fixed commitments; the reliable half of the store |
| `inbox.org` | captured TODOs, mostly undated | the candidate pool. Its header comment defines the `@tag` taxonomy (`@meeting`, `@research`, `@reading`, `@coursework`, `@admin`, `@errand`, `@leisure`) — group by those tags rather than inventing categories |
| `inbox-recurring.org` | habits carrying Org repeaters, already tracked by Emacs' habit system | not candidate work. Name a habit only when its repeater has lapsed |
| `backlog.org` | archive of items captured under a previous affiliation | skip for a daily brief; open it only when asked about dormant or historical items |
| `gcal.org`, `schedule.org` | superseded by the two generated calendars | ignore |

A capture file's own age is a reading: one untouched for months means nothing
was captured, not that nothing is pending.

## Rules

- Undated captures are the ones that rot. Age each from its capture timestamp
  and say how long it has sat — an item nobody dated is one nobody decided
  about.
- Treat scheduled items, deadlines, and meetings as constraints, not
  automatically as highest priority.
- Distinguish fixed commitments from optional work.
- Prefer a small daily plan: 1–3 must-do items plus a short backup list.
- Do not mutate Org files, reschedule tasks, mark TODOs done, or create daily
  notes.
- Ask only for missing context that materially changes today's plan.
- When the brief runs on a schedule rather than by request: key it to the
  intended calendar date, not the run time; after a gap produce one current
  brief, never one per missed day; skip if today's brief artifact already
  exists; and record a skipped or caught-up day in the brief itself rather
  than staying silent about it.

## Workflow

1. Identify today's date, day phase, and available work window.
2. Read today's fixed commitments from the generated calendars.
3. Read `inbox.org` for candidates: each item's `@tag` and how long it has sat
   undated.
4. Check `inbox-recurring.org` only for repeaters that have lapsed.
5. Separate fixed commitments from candidate tasks; find conflicts and overload.
6. Use `decide-priority` when ranking candidates requires explicit tradeoffs.
7. Produce the brief, and close the loop: emit the proposed dates as an org
   snippet the user can yank. Read-only means the processing step depends on
   them acting, so make acting a paste rather than a re-derivation.
8. Route into the relevant execution skill only after the user confirms.

## Output Shape

```markdown
## Morning Brief

### Agenda / Fixed Commitments
- ...

### Must Do Today
1. ...
2. ...
3. ...

### Good Next Tasks
- ...

### Stale Captures (undated, invisible to the agenda)
- <item> — captured <date>, <n> days undated

### Lapsed Habits (omit when none)
- <habit> — repeater due <date>

### Risks / Conflicts
- ...

### Recommended First Action
...

### Proposed Dates — yank into Emacs
```org
SCHEDULED: <YYYY-MM-DD day>
```

### If Low Energy
...

### If Deep Work Window
...
```

## Routing

- Use `decide-priority` when choosing among competing tasks or tradeoffs.
- Use `plan-interview` when today's constraints or goals are too ambiguous to plan directly.
- Use `research-protocol` before academic-paper, literature, citation, related-work, bibliography, author-lookup, or field-survey content.
- Use `research-run` when today's next action is experiment/log/result follow-up.
- Use `dev-*` or `debug-*` only after a concrete software task or bug is selected.
- Use `dev-verification` when checking whether a claimed status is actually complete.

## Anti-Patterns

- Starting implementation before the day plan is confirmed.
