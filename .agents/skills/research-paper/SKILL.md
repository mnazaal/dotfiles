---
name: research-paper
description: Use for one research paper: read, discuss, analyze, ingest PDF/URL/arXiv/DOI/pasted text, extract contribution, method, evidence, limitations, critique, follow-up papers.
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

For non-PDF external sources (URLs, arXiv links, pasted text, transcripts): classify source type, extract/normalize text and metadata, preserve provenance (source path/URL, access date) before analysis.

## Boundary

- This skill analyzes research content.
- Use `context-pdf` for PDF mechanics: OCR, page extraction, merging, splitting, forms, encryption, or artifact transforms.
- `~/org` is read-only for agents (AGENTS.md); keep research citation/verification rules here via `research-protocol`.

## Related Skills

- `context-pdf` for PDF extraction.
- `research-lit-search` for surrounding literature.
- `research-protocol` for citation verification; `research-session` for idea triage.
