#!/usr/bin/env sh
# Register the shared MCP server (asta-mcp) at user scope for Claude Code.
# Idempotent: the server is removed (if present) then re-added, so the script is
# safe to re-run.
#
# The key is not baked in here, and no longer travels in the environment either.
# `claude mcp add --header 'x-api-key: ${ASTA_MCP_API_KEY}'` stores the header
# literally and expands it from the environment at connect time, which only
# works when something exported it first -- that was the launcher's job, and it
# is why a bare `claude` reports "Missing environment variables:
# ASTA_MCP_API_KEY". headersHelper instead runs a command at connect time and
# merges its stdout into the request headers, so the key goes straight from
# `pass` into the header on any launch path.
#
# There is no CLI flag for headersHelper, so it is written into the user config
# directly: `claude mcp add` creates the entry, jq swaps the static header for
# the helper.
#
# Note: deepwiki and grepika were intentionally dropped to reduce per-session
# context/token cost (grepika also ships a large instructions block). Claude uses
# native Grep/Glob + the Explore subagent for code search instead. Re-add with:
#   claude mcp add -s user --transport http deepwiki https://mcp.deepwiki.com/mcp
#   claude mcp add -s user grepika -- bunx -y @agentika/grepika --mcp
set -eu

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
pass show asta-mcp >/dev/null || { echo "pass entry 'asta-mcp' is missing" >&2; exit 1; }

config="$HOME/.claude.json"

reset() { claude mcp remove --scope user "$1" >/dev/null 2>&1 || true; }

reset asta-mcp
claude mcp add --scope user --transport http asta-mcp \
	https://asta-tools.allen.ai/mcp/v1

# Single-quoted so this stays a command for Claude to run later, not something
# this script expands now. Its stdout must be a JSON object of headers.
helper='printf "{\"x-api-key\": \"%s\"}" "$(pass show asta-mcp)"'

tmp=$(mktemp)
# Via a temp file so a jq failure cannot truncate the live config.
jq --arg h "$helper" \
	'.mcpServers["asta-mcp"] |= (del(.headers) | .headersHelper = $h)' \
	"$config" >"$tmp"
mv "$tmp" "$config"

echo "Done. Verify with: claude mcp get asta-mcp"
echo "It should show headersHelper and no x-api-key header, and 'claude mcp list'"
echo "should report Connected with no 'Missing environment variables' warning."
