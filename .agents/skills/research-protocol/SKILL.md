---
name: research-protocol
description: Mandatory for academic papers, literature, citations, related work, author lookup, field surveys, bibliographies; verify papers/citations, no fabricated citations, load before external academic/literature claims.
---

# Skill: Research Protocol

## Iron Rules

- Do not cite papers from memory.
- Verify papers/citations/authors with configured paper-search tools before citing.
- Verifying an identifier is not verifying a claim. When a paper's *content* — what it assumes, proves, or requires — will change a design, a plan, or a risk entry, confirm that content against the paper itself (snippet or full-text search), not against a summary, whether yours or a subagent's. Batch metadata lookups confirm existence only.
- Tool and snippet output may be lossy: some harnesses strip stopwords and numerals, so a figure read through a search tool can be silently wrong or missing entirely, and the loss looks like the source being redacted rather than the channel degrading it. Verify any number — and any quote whose force depends on a number — against fetched full text, not against snippet output.
- For broad literature or field surveys, use the configured literature-search workflow.
- If verification tools are unavailable, say so before giving unverified memory-based context.
- Load this protocol before producing externally sourced academic, citation, related-work, author, metadata, bibliography, or field-survey claims. Purely local experiment interpretation or project orientation may route directly to `research-run`/`research-session` until it makes literature claims.
- Verification can be partial: a paper/method's qualitative spec (e.g. "SCM prior samples a shared per-dataset activation from {Tanh, LeakyReLU, ELU, Identity}") may be confirmed via search while exact numeric hyperparameters (a specific table's ranges/constants) are not retrievable through available tools. In that case, implement the verified distribution *family*/structure faithfully, and explicitly label every unretrieved number as an illustrative default in the code/doc — not invented-but-uncited, not a blocker. Don't silently fill gaps with memory-based numbers and don't refuse the whole task over one unretrievable table.

## Routing

- Specific paper or PDF: verify metadata, then use `research-paper`.
- Related work, key papers, or subfield map: use `research-lit-search`.
- Before investing in BUILDING a new method/contribution (not just writing it up): run the novelty gate (`research-lit-search`) FIRST — "already done" is far cheaper to find before implementation than after.
- Session orientation ("catch me up") or evaluating a research idea/direction: use `research-session`; `decide-priority` for general action ranking.
- Experimental result interpretation: use `research-run`; if broken, hand off to `debug-ml-research`.
- Note import/export mechanics: `context-pdf`; Org notes are read-only for agents (AGENTS.md).

## Self-Check Before Answer

- Every cited paper was verified through configured tools or clearly marked unverified.
- No author, venue, year, DOI, or claim is invented from memory.
- Broad claims distinguish evidence from interpretation.
- Storage/writes follow host policy and avoid protected personal stores unless user allows.

## Related Skills

- `research-paper` for one paper.
- `research-lit-search` for related work or subfield maps.
- `research-session` for session orientation and idea triage.
- `research-run` for experiment evidence.
- `decide-priority` for action selection under uncertainty.
