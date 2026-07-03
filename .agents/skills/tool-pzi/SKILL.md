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
- All commands accept `--config PATH` and `--target NAME` to select a non-default library.

## Workflow

**Add a paper:**
```bash
pzi add <doi|url|pdf>
pzi add <doi> --tags systems,classic --json
pzi add --from-file dois.txt --failures-out failed.txt   # bulk
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

**Validate citations (read-only, never writes):**
```bash
pzi check --strict --report audit.json
```

**Fill missing metadata / promote preprints:**
```bash
pzi update                   # whole library
pzi update smith2024graph    # single entry
pzi update --promote         # replace preprint citekeys with published versions
```

**Tags and maintenance:**
```bash
pzi tag --add systems smith2024graph
pzi tag --list
pzi fix --dedupe
pzi delete smith2024graph
```

## Related Skills

- `research-protocol` before citing library entries in academic work.
- `research-lit-search` for discovering new papers to capture.
- `context-org` when saving exports as Org notes.
