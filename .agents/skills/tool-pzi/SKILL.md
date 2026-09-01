---
name: tool-pzi
description: Use when the task involves the user's personal paper library: adding papers by DOI/URL/PDF, searching entries, exporting BibTeX, checking or updating citation metadata.
---

# Skill: tool-pzi

pzi is a local BibTeX library manager. Papers are added from DOIs, URLs, or PDFs and stored in `.bib` files.

## Rules

- Use `--json` for any output you need to parse; plain-text format is for humans and unstable.
- Do not assume config or library path. If unclear, run `pzi doctor` first.
- `pzi add` is idempotent — re-adding an existing DOI will not duplicate it.
- Use the CLI for one-off tasks. HTTP API (`pzi server`, port 8765) is for the browser extension; only use it if the server is already running.
- Confirm command support from the installed help when using non-default options such as `--config PATH` or `--target NAME`.
- Before mutating a library (`add`, `inbox`, `import`, `update`, `tag`, `delete`, `pdf`, `library clean --fix`/`merge`/`reindex`), confirm the target library/config and summarize the intended mutation; proceed only with user authorization.
- Nonzero exit is not necessarily failure: 1 means ran fine with something to report (no matches, duplicates, integrity issues), 3 entry not found, 4 batch partly failed, 5 could not run. Read the output, not just the status.
- Boundary: use pzi for bibliographic metadata, citekeys, tags, and BibTeX export. Use `tool-cementic` for full-text semantic retrieval; combine them only when both are requested.

## Workflow

**Add a paper:**
```bash
pzi add <doi|url|pdf>
pzi add <doi> --tags systems,classic --json
pzi add --from-file dois.txt --failures-out failed.txt   # bulk
pzi inbox ~/papers/inbox.txt       # drain an inbox file: adds each line, keeps failures
```

**Search:**
```bash
pzi search --query "graph neural" --json
pzi search --author hinton --year 2015
```

**Browse / look up:**
```bash
pzi entries                        # list (paginated)
pzi entries smith2024graph --json  # full record for one citekey
pzi entries --stats
```

**Export:**
```bash
pzi export                         # BibTeX to stdout
pzi export --format json | jq .
```

**Validate citations (read-only; writes only the requested report file):**
```bash
pzi library check --strict --report audit.json
pzi library check --limit 20     # a whole library takes hours (rate-limited providers)
```

**Fill missing metadata / promote preprints:**
```bash
pzi update                           # fill gaps only; never replaces preprints
pzi update --promote --dry-run       # preview; promote replaces the preprint in place, keeping its citekey
pzi update --promote --keep-preprint # create the published entry beside the preprint instead
pzi update --promote --limit 10      # a full sweep is hours (rate-limited providers)
```

**Tags and maintenance:**
```bash
pzi tag add smith2024graph systems
pzi tag list
pzi library dedupe
pzi library clean --fix          # move orphan PDFs
pzi pdf retry --failed-only      # re-attempt missing PDF downloads
pzi delete smith2024graph        # moves its PDF to papers/.orphans/ unless --keep-pdf
```

## Related Skills

- `research-protocol` before citing library entries in academic work.
- `research-lit-search` for discovering new papers to capture.
- `tool-cementic` for full-text semantic search over local papers.
- Org-note exports: propose as snippets — `~/org` is read-only for agents (AGENTS.md).
