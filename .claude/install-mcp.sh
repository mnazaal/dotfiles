#!/usr/bin/env sh
# Register the shared MCP server (asta-mcp) at user scope for Claude Code.
# Idempotent: the server is removed (if present) then re-added, so the script is
# safe to re-run.
#
# The asta-mcp key is NOT baked in here: the header is stored literally as
# ${ASTA_MCP_API_KEY} and expanded at runtime. Launch Claude via `renv claude`
# so ~/.config/renv/claude.sh exports it from `pass show asta-mcp`. This script
# itself does not need the key set.
#
# Note: deepwiki and grepika were intentionally dropped to reduce per-session
# context/token cost (grepika also ships a large instructions block). Claude uses
# native Grep/Glob + the Explore subagent for code search instead. Re-add with:
#   claude mcp add -s user --transport http deepwiki https://mcp.deepwiki.com/mcp
#   claude mcp add -s user grepika -- bunx -y @agentika/grepika --mcp
set -eu

reset() { claude mcp remove --scope user "$1" >/dev/null 2>&1 || true; }

# Single quotes keep ${ASTA_MCP_API_KEY} literal so Claude expands it at connect time.
reset asta-mcp
claude mcp add --scope user --transport http asta-mcp \
  https://asta-tools.allen.ai/mcp/v1 \
  --header 'x-api-key: ${ASTA_MCP_API_KEY}'

echo "Done. Verify with: claude mcp list  (run via 'renv claude' for asta auth)"
