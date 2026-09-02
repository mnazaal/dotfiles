---
name: research-lit-search
description: Use for literature search: related work, paper search, field survey, subfield map, topic/method/query papers, citation/reference exploration, research clusters and gaps.
---

# Skill: Research Lit Search

## Rules

- Load `research-protocol` first.
- Search from multiple angles: keywords, methods, venues, authors, citations, references.
- Author expansion is secondary to citation/reference edges (an author edge is a weaker topical signal — people pivot subfields and co-author across topics). Use it to map who is active, not as the primary recall lever.
- Citation and reference edges are the recall lever, not an option. A sweep that made zero citation/reference-edge calls has not been run, however many keyword queries it issued.
- Do not over-rank unverified or weakly relevant papers.
- Record what a paper ESTABLISHES, not what it is about. "A survey of X" is not a record; "orders X by data scope in §2, Definitions 2.4–2.9" is. A paper filed by topic cannot later tell you it already contains your contribution.
- Preserve query strings, source metadata, and uncertainty.
- Search the user's own corpus FIRST, before the external sweep — it is the cheapest recall step, not an optional extra: prior projects' literature notes and the personal note store, at the locations the global instructions and `context-project-docs` define. Prefer semantic retrieval if a semantic-search tool is configured; fall back to text search. Report which corpora you checked and what they already covered. Two distinct failures this prevents: re-deriving a subfield's anchor papers once per project, and dropping a paper that an earlier cross-project survey found but no project ever inherited.

## Workflow

1. Clarify scope if ambiguous.
2. Run broad and targeted searches.
3. Cluster results by problem/method/assumption. Scope at least one cluster by *problem*: method-scoped clusters systematically miss work attacking the same problem by a different route, and that work is invisible from inside every other cluster.
4. Identify anchors, recent work, baselines, and gaps.
5. If citation/reference expansion leaves a coverage gap, expand by author best-first, not breadth-first: take the authors of the top-ranked results, follow each author's other work, but cap to a few authors, keep only papers that pass the same relevance gate, and flag when a cluster is dominated by one lab. Fold survivors back into the clusters.
6. Return map: clusters, representative papers, why each matters, caveats, next reads.

## Novelty gate

When the search is a novelty gate (routed from `research-protocol` before building a new
method), the output is sharper than a field map:

- For each nearest neighbor, name the single defining feature it is missing — not a vague
  "it differs".
- State the defensible delta as the *combination* no single paper has, and lead with it.
- Assess scooping risk: which labs/authors are adjacent and iterating, and on which leg.
- Record an explicit "what NOT to re-pursue" — answered searches and dead ends — so a later
  session does not re-run them. Name the sink: the project's literature notes when the work
  has a project, otherwise the cross-project store (locations per the global instructions and
  `context-project-docs`). A dead end recorded only in chat is a dead end that gets re-run.
- Expect concept-occupied, machinery-open. Ask what each nearest neighbor failed to build, not whether the idea is taken — it usually is.
- A null result licenses "no paper states this", never "nobody noticed this".
  Elementary facts go unwritten because they are elementary, so absence is evidence
  about the literature and not about what practitioners know. Claim the measurement
  and its consequences; do not claim priority over a lemma.
- End on a verdict: survives/pursue (with any narrowed framing) vs. scooped/pivot.
- A kill verdict closes the gate, not the literature. One sufficient counterexample kills a claim, so a kill survives thin coverage — but it establishes nothing about what the field cannot do. If the project continues, re-open with the limitation question, whose stopping condition is breadth enough to separate an incidental limitation from a structural one.

## Related Skills

- `research-paper` for deep reading of a result from the search.
- `research-session` for idea triage and implications.
