# Global instructions for Claude Code

@~/.agents/AGENTS.md

## Claude Code specifics

The shared rules above are written tool-agnostically (for the opencode/pi
agents). Map their tool names onto Claude Code as follows:

- **Code search** — `grepika` is not enabled for Claude Code (dropped to save
  per-session context; it ships a large instructions block). Use the native
  `Grep`/`Glob` tools, and the `Explore` subagent for broad fan-out searches.
  Avoid raw `rg`/`grep`/`find` via `Bash` for code discovery. The `grepika` rules
  in AGENTS.md apply to the opencode/pi agents, which keep it.
- **File inspection/edit** — use `Read`/`Edit`/`Write`, never `cat`/`sed`/`awk`.
- **Docs** — `deepwiki` is not enabled for Claude Code (dropped to save
  per-session context); use `WebFetch`/`WebSearch` for library/API docs. The
  `deepwiki` rule in AGENTS.md applies to the opencode/pi agents, which keep it.
- **Papers** — use the configured academic-paper verification tool before citing
  a paper; never cite an unverified paper.
- **Subagents** — delegate via the `Task` tool. The agents in `~/.claude/agents/`
  are the equivalent of the opencode/pi subagents.
- **Python tests** — run `pytest` / `pytest <path>` only. Never `python -m
  pytest`, `.venv/bin/python -m pytest`, or `uv run pytest`. Use `uv` for
  environment/dependency management only.

## Style

Default to concise, high-signal output: bullets, tight phrasing, expand only when
asked.
