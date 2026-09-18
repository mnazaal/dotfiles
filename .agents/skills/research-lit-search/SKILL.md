---
name: research-lit-search
description: "Use for literature search: related work, paper search, field survey, subfield map, topic/method/query papers, citation/reference exploration, research clusters and gaps."
---

# Skill: Research Lit Search

## Rules

- Load `research-protocol` first.
- Search from multiple angles: keywords, methods, venues, authors, citations, references.
- Author expansion is secondary to citation/reference edges (an author edge is a weaker topical signal — people pivot subfields and co-author across topics). Use it to map who is active, not as the primary recall lever.
- Citation and reference edges are the recall lever, not an option. A sweep that made zero citation/reference-edge calls has not been run, however many keyword queries it issued.
- The configured search tool is one provider; the edge calls do not have to go through it. `references/` beside this skill holds the query shapes for keyless HTTP sources: `openalex.md` and `opencitations.md` (citation and reference edges), `crossref.md` (DOI metadata), `unpaywall.md` (an open copy for a DOI), `arxiv.md` (Atom API, not JSON), `semantic-scholar.md` (raw HTTP when the configured tool's rate limit bites). Open the one the step needs; each carries the date its figures were verified.
- Do not over-rank unverified or weakly relevant papers.
- Record what a paper ESTABLISHES, not what it is about. "A survey of X" is not a record; "orders X by data scope in §2, Definitions 2.4–2.9" is. A paper filed by topic cannot later tell you it already contains your contribution.
- Preserve query strings, source metadata, and uncertainty.
- Report DROPPED sources beside kept ones: title plus the one-line reason it
  was excluded. A sweep that lists only what it kept is unfalsifiable — the
  reader cannot tell a paper that was considered and rejected from one that was
  never found, and the next sweep re-litigates the same rejects from scratch.
- Search the user's own corpus FIRST, before the external sweep — it is the cheapest recall step, not an optional extra: prior projects' literature notes, the cross-project store the global instructions name, and the personal Org note store. Prefer semantic retrieval if a semantic-search tool is configured; fall back to text search. Report which corpora you checked and what they already covered. Two distinct failures this prevents: re-deriving a subfield's anchor papers once per project, and dropping a paper that an earlier cross-project survey found but no project ever inherited.

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
- Render the positioning as a table: one row per related work, one column per
  axis the problem makes matter, our own method as the final row. The cell says
  how that work stands on that axis, so the empty cells are the gaps and the
  reader sees the combination rather than being told about it.
- A null result carries its boundary. "Nobody has done this" is only weighable
  beside what was searched: the cutoff date, the sources covered, the languages,
  and what was reachable without a subscription. Unbounded, the gate's negative
  cannot be re-judged later and quietly expires as the literature moves.
- Fix the columns from what the problem demands, BEFORE filling in our own row.
  Columns chosen after the fact produce a last row that sweeps every one of
  them, which is the shape a reviewer discounts on sight — it reads as axes
  picked so we win. An axis we do not clear stays as a column and becomes a
  stated limitation; deleting it is what makes the table untrustworthy.
- Assess scooping risk: which labs/authors are adjacent and iterating, and on which leg.
- Record an explicit "what NOT to re-pursue" — answered searches and dead ends — so a later
  session does not re-run them. Name the sink: the project's literature notes when the work
  has a project, otherwise the cross-project store the global instructions name (`## Cross-project
  store` below). A dead end recorded only in chat is a dead end that gets re-run.
- Expect concept-occupied, machinery-open. Ask what each nearest neighbor failed to build, not whether the idea is taken — it usually is.
- A null result licenses "no paper states this", never "nobody noticed this".
  Elementary facts go unwritten because they are elementary, so absence is evidence
  about the literature and not about what practitioners know. Claim the measurement
  and its consequences; do not claim priority over a lemma.
- End on a verdict: survives/pursue (with any narrowed framing) vs. scooped/pivot.
- A kill verdict closes the gate, not the literature. One sufficient counterexample kills a claim, so a kill survives thin coverage — but it establishes nothing about what the field cannot do. If the project continues, re-open with the limitation question, whose stopping condition is breadth enough to separate an incidental limitation from a structural one.

## Author or lab corpus

When the query names a lab, a principal investigator, or an author rather than
a topic, the shape is different from a topic sweep and the topic workflow
above mis-serves it.

- Resolve identity first, and do it in the lead context rather than
  delegating: same-name authors, moved affiliations, and a lab's rotating
  first authors are exactly what a delegated search silently merges.
- Build the publication list before any synthesis is delegated: titles, years,
  venues, DOIs. Synthesis over an unresolved list inherits every identity
  error and cannot be checked afterwards.
- Map three to five research trajectories through the list, ranked by
  contrastive originality — what this group did that adjacent groups did not —
  rather than by citation count or prestige. The trajectories, not the list,
  are the deliverable.

## Cross-project store

When the work has no project home, the sink is the cross-project literature
store the global instructions name; if none is named, ask for one rather than
inventing a location. One slug-named entry per query. A re-run extends the
existing entry instead of opening a second. Each paper carries its citation,
venue, link, kept/rejected with the reason, and any notes; write totals after
the last entry, not before.

## Related Skills

- `research-paper` for deep reading of a result from the search.
- `research-session` for idea triage and implications.
