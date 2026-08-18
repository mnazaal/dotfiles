---
name: dev-scout
description: Use for read-only codebase/repo exploration: scout repo, map architecture, entry points, modules, APIs, interfaces, seams, sticky parts, risks, missing tests/docs, no code changes.
---

# Skill: Dev Scout

## Rules

- Read-only. Do not edit code.
- Discover architecture, entry points, seams, generated files, configs, tests, and sticky parts.
- Cross-check headline doc/README API claims against the code; a documented-but-
  unimplemented or stale feature is a top-tier gap, not a footnote.
- Surface findings, not exhaustive inventories.
- Do not debug or implement; route suspicious paths to `debug-*` or gaps to `dev-*`.

## Workflow

1. Read project signals: README, package/config files, CI, lockfiles, tests.
2. Map directory structure and entry points.
3. Trace one or two key flows end to end.
4. Identify interfaces, adapters, generated/derived directories, and fragile assumptions.
5. Report entry points, main modules/interfaces, external services/adapters, generated or derived files, sticky assumptions/risks, gaps, and suggested next skill.

For large external artifacts (repos, logs, transcripts, terminal output) ingested before scouting: classify source type, extract/normalize text and metadata, preserve timestamps and file refs, then return source, kind, normalized content, and caveats before proceeding with the workflow above.

## Output Shape

- Architecture overview.
- Entry points.
- Key interfaces and seams.
- Sticky parts.
- Gaps.
- Suggested next skill.

## Related Skills

- `debug-*` for suspicious broken paths.
- `dev-*` for implementation after scouting.
- `understand-codebase` when the findings are for the user to internalize rather than
  for an agent to act on; it calls this skill for the mapping.
