---
name: research-lit-search
description: Use for literature search: related work, paper search, field survey, subfield map, topic/method/query papers, citation/reference exploration, research clusters and gaps.
---

# Skill: Research Lit Search

## Rules

- Load `research-protocol` first.
- Search from multiple angles: keywords, methods, venues, authors, citations, references.
- Author expansion is secondary to citation/reference edges (an author edge is a weaker topical signal — people pivot subfields and co-author across topics). Use it to map who is active, not as the primary recall lever.
- Do not over-rank unverified or weakly relevant papers.
- Preserve query strings, source metadata, and uncertainty.
- With user authorization or an already-declared workspace boundary, search the user's own workspace too: sibling project repos, their `notes/`/`lit.md`, and prior sessions. A "new" direction often already lives in an adjacent project the user is running.

## Workflow

1. Clarify scope if ambiguous.
2. Run broad and targeted searches.
3. Cluster results by problem/method/assumption.
4. Identify anchors, recent work, baselines, and gaps.
5. If citation/reference expansion leaves a coverage gap, expand by author best-first, not breadth-first: take the authors of the top-ranked results, follow each author's other work, but cap to a few authors, keep only papers that pass the same relevance gate, and flag when a cluster is dominated by one lab. Fold survivors back into the clusters.
6. Return map: clusters, representative papers, why each matters, caveats, next reads.

## Related Skills

- `research-paper` for deep reading of a result from the search.
- `research-session` for idea triage and implications.
