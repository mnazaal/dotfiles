# Global instructions for Claude Code

@~/.agents/AGENTS.md

## Claude Code specifics

The shared rules above are written tool-agnostically (for the pi agent). Map their tool names onto Claude Code as follows:

- **Code search** — use the native `Grep`/`Glob` tools, and the `Explore`
  subagent for broad fan-out searches. Avoid raw `rg`/`grep`/`find` via `Bash`
  for code discovery.
- **File inspection/edit** — prefer `Read`/`Edit`/`Write` for edits. 
  Never pair `cd` with a relative file read in one Bash command — use an absolute
  path. For `grep`/`rg`/`diff`/`git`/`cp`/`mv`, Claude Code 2.1.259+ always
  prompts for that shape while any `Read()` deny rule exists, even under
  `bypassPermissions`.
- **Docs** — use `WebFetch`/`WebSearch` for library/API docs.
- **Subagents** — delegate via the `Agent` tool. The agents in `~/.claude/agents/`
  are the equivalent of pi's subagents.

## Memory store

The cross-session memory is file-per-fact with a `MEMORY.md` index. Two rules,
both learned by being bitten:

- **The index is a summary frozen at write time.** It is what loads every
  session, so it is what gets quoted — and a fact superseded INSIDE its own file
  does not propagate to the line pointing at that file. A figure was quoted from
  an index line that its own file marked stale, and was wrong by 5x. So: when a
  fact is superseded, edit the index line in the SAME pass, or make the index
  line say to open the file. Before quoting any number from an index line, open
  the file.
- **Nothing retires a memory, so the store only grows.** Prefer rewriting an
  existing file over adding a sibling, merge two entries that cover one topic,
  and delete what turned out wrong rather than leaving it beside its correction.
  Reserve additions for facts that will still matter in a month. If the index
  passes roughly 60 lines, spend a pass merging before adding.

## Style

Default to concise, high-signal output: bullets, tight phrasing, expand only when
asked.
