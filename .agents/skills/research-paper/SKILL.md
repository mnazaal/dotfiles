---
name: research-paper
description: "Use for one research paper: read, discuss, analyze, ingest PDF/URL/arXiv/DOI/pasted text, extract contribution, method, evidence, limitations, critique, follow-up papers. Also BEFORE a plan, design, or risk entry depends on what a method does, assumes, or cannot conclude — read the source rather than an abstract or a prior note, including papers already stored locally."
---

# Skill: Research Paper

## Rules

- Load `research-protocol` first for externally sourced academic, citation, metadata, bibliography, or literature claims.
- Separate what paper claims from your critique.
- Track uncertainty: missing sections, extraction errors, unverified metadata.
- Use host/global storage policy for notes.

## Workflow

1. Identify and verify paper if possible.
2. If source is a PDF and text extraction is needed, use `context-pdf` first.
3. Extract title, authors, venue/year, abstract, problem, method, evidence, limitations.
4. Summarize contribution and assumptions.
5. Critique claims, evidence, and fit to user goal. Use normal evidence/limitations analysis here; route a requested adversarial stress-test of a specific claim to `critique-argument`.
6. If ingesting, write note only to allowed location.
7. Suggest follow-up papers/questions.

## Ingesting External Sources

For non-PDF external sources (URLs, arXiv links, pasted text, transcripts): preserve provenance (source path/URL, access date) before analysis.

A long document is read from disk in bounded windows, never pulled whole into
the context. A fetch tool's return value enters the context directly, so
download instead (`curl -sL -o <file> <url>`) and read from the file.

- Guards before anything else: under 50 bytes is an empty or error response,
  stop; over 1 KB with fewer than 100 readable characters is binary, stop.
- Tier by size. Under about 8k characters, read directly. Up to about 60k,
  read in windows. Above that, split into chunks and read them in parallel
  (`agent-orchestration`), one chunk per reader.
- Append notes to disk after each window and before opening the next, so an
  interrupted read keeps what was already done.
- Size the overlap between chunks so a claim that straddles a boundary appears
  whole in at least one of them; mark one that still arrives severed as
  `BOUNDARY PARTIAL` and resolve it when the chunk notes are merged.
- A chunk that could not be read is reported, not skipped silently: the merged
  note ends with a coverage-gaps line naming the missing chunk indices, so the
  reader knows which sections the summary does not cover.

## Boundary

- This skill analyzes research content.
- Use `context-pdf` for PDF mechanics: OCR, page extraction, merging, splitting, forms, encryption, or artifact transforms.
- Keep research citation/verification rules here via `research-protocol`.

## Related Skills

- `context-pdf` for PDF extraction.
- `research-lit-search` for surrounding literature.
- `research-protocol` for citation verification; `research-session` for idea triage.
