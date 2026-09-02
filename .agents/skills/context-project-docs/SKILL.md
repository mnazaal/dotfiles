---
name: context-project-docs
description: Use before creating or editing standing project Markdown or naming files in notes/: PLAN.md, CONTEXT.md, LOG.md, README, CHANGELOG, SUMMARY/NOTES/TODO-style project files; canonical doc set, notes/ naming and reserved files (main.html, claims.md), no document proliferation, conciseness rules.
---

# Skill: Context Project Docs

## Canonical Set

A project carries four standing documents — next, past, vocabulary, outward — each created lazily on first real content:

- `PLAN.md` — decisions, execution order, risks (what's next). Shape owned by `research-plan`.
- `LOG.md` — prepend-only run/result log, newest entry at top (what happened). Entries follow the canonical LOG ordering below.
- `CONTEXT.md` — terminology glossary, the shared vocabulary. Entries owned by `plan-interview`.
- `README.md` — the outward-facing snapshot for someone not in the project. For research-code repos, include a `research-map`-generated, provenance-stamped Overview block.
`PLAN.md` additionally carries the cross-session state block in a delimited `session-handoff:begin/end` region directly below the title — content, write gates, and replace-never-append rules all owned by `session-handoff`. No separate handoff document — that would be a fifth standing doc for ten lines.

## Rules

- Create no standing markdown outside the canonical set without asking. Agents minting `SUMMARY.md`, `NOTES.md`, `IMPLEMENTATION.md`, `TESTING.md` is the failure mode this skill exists to stop.
- No `CHANGELOG.md`: conventional commits + `git log` are the changelog; there are no external consumers and no backcompat obligation (`dev-ponytail`).
- Scratch analysis goes to chat or the scratchpad; decisions go to `PLAN.md`; results go to `LOG.md`; where-the-work-stands goes to `PLAN.md`'s `session-handoff` block.
- `LOG.md` holds runs and results, not session summaries. A session handoff appended here is a single-valued record stored append-only: every superseded copy stays in the read path forever and dilutes the results the log exists for (`session-handoff`).
- For ML research repos, the standard layout includes root `README.md`, `PLAN.md`, `LOG.md`, and `notes/`. Keep the first three as standing docs; keep detailed working/research notes under `notes/` (named per the notes/ section below) and point to them from PLAN/LOG instead of duplicating their narrative.
- Write as tersely as the content allows: no restated context, no filler sections, no empty headings. **One fact, one home** — a LOG/PLAN entry is a verdict + the load-bearing numbers + a pointer to the detailed artifact (`notes/` file, commit), not a re-narration of it; if it restates what another doc already holds, cut it to a one-line pointer. (`session-handoff` inlines key *numbers* so they survive, not the narrative — the narrative has one home.)
- `LOG.md` is prepend-only and newest first — insert new entries at the top; corrections are new entries, never rewrites.
- Canonical `LOG.md` ordering: file order is reverse chronological; within each entry use heading/date first, then verdict/summary, load-bearing evidence or numbers, pointers to artifacts/commits/notes, next action, and any explicit correction/supersedes link.
- Docs describing code (README claims, usage examples, docstrings) update in the same commit as that code, or the commit message says why not — `dev-scout` treats doc/code mismatch as a top-tier gap.
- For research-code repos, a current-state overview is persisted only in `research-map`'s two stamped forms — README's delimited `research-map:begin/end` block (the gist) and `notes/main.html` (the full map) — regenerated, never hand-maintained. Never mint a separate `OVERVIEW.md`/`SUMMARY.md`: a hand-kept snapshot silently drifts; a stamped generated form shows its own staleness.
- Create each file lazily, on first real content.
- Boundary: this skill governs standing project Markdown. `learn-topic` may create its own learning-workspace `MISSION.md`/`CONTEXT.md`/`LOG.md` files; those are scoped to the learning workspace, not general project standing docs.

## notes/

The full doc inventory is bounded: the four standing docs above, two reserved `notes/` files, and prefixed working notes. Nothing else — among notes; non-note artifacts a note references (figure assets, generated run outputs) sit outside this vocabulary, not in violation of it.

Reserved files, each with one owner:

- `main.html` — the project map and front door of `notes/`. Written only by `research-map` (full form), provenance-stamped, regenerated top-to-bottom, never hand-edited. Its opening lines point to `claims.md` and `PLAN.md`.
- `claims.md` — the claims/evidence ledger: curated primary state — user and agent edit it in ordinary commits; never regenerated. Shape owned by `research-manuscript-workflow`.

All other notes are prefixed working notes (closed vocabulary):

- `deriv-` derivations · `design-` method/experiment designs · `lit-` related-work and lit maps · `review-` adversarial/full reviews · `draft-` per-section briefs and paper-draft fragments (shape owned by `research-manuscript-workflow`) · `probe_*.py` analysis scripts.
- A prose note fitting no prefix is a signal the content belongs in chat or the scratchpad, not `notes/`.
- Working notes are one-per-topic, many-per-prefix: if an existing note's scope covers the new content, rewrite that note (git keeps the history; the moving git date is the recency signal) rather than minting a sibling or adding a superseded-banner. Content removed as stale is visible in the commit diff — review it there.

No dates in filenames. The date of record is git (`git log -1 --format=%cs -- <file>`); mtime is a local convenience that dies on re-clone. The naming rules apply to new files — no bulk renames of existing projects' notes. Exception: when a one-per-topic rewrite touches a legacy-named note, `git mv` it to the convention in the same commit — a single opportunistic rename is not a bulk rename, and it keeps a stale filename date off fresh content.

## Related Skills

- `research-plan` for PLAN.md content.
- `plan-interview` for CONTEXT.md glossary entries.
- `research-run` for the LOG.md entry shape.
- `research-map` for README's generated Overview block and `notes/main.html`.
- `dev-ponytail` for the deletion bias behind all of this.
