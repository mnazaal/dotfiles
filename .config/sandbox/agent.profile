# agent — shared base for coding-agent harnesses. Composes the generic `dev`
# profile from this same sandbox profile directory.
use dev

RO+=(
	"$H/.agents"       # AGENTS.md + shared skills
	"$H/.config"
	"$H/.local"        # user-installed bins/libs (cargo, go, …)
	"$H/org/roam"      # org-roam notes (read-only for agents)
)
RW+=(
	"$H/dotfiles"               # stow symlink targets + agent config work
	"$H/.cache"                 # tool caches (bun, uv, pip, …)
	"$H/.local/share"           # uv python installs, bun packages, …
	"$H/.local/state/nvim"      # Neovim LSP logs/state for in-agent editors
	"$H/.local/state/headromm"  # Headroom MCP logs/state for in-agent editors
	"$H/org/agents"             # shared agent wiki (read-write)
	"$H/projects"               # all projects — agents often need to cross-reference
)

# Agent enforcement code — bound read-only AFTER the writable $H/dotfiles bind
# above, which contains all of it. The read-only binds on $H/.agents and
# $H/.config do NOT cover these: both trees are stow symlinks whose targets live
# under $H/dotfiles, so without this block an agent can rewrite its own
# guardrails, hooks, or this sandbox script by writing the symlink target.
# Editing machinery is a deliberate out-of-sandbox action.
RO_LAST+=(
	"$H/dotfiles/.agents/guardrails"
	"$H/dotfiles/.claude/hooks"
	"$H/dotfiles/.claude/settings.json"
	"$H/dotfiles/.config/codex/hooks"
	"$H/dotfiles/.config/codex/hooks.json"
	"$H/dotfiles/.config/codex/config.toml.template"
	"$H/dotfiles/.config/opencode/plugins"
	"$H/dotfiles/.config/opencode/opencode.jsonc"
	"$H/dotfiles/.config/pi/agent/extensions"
	"$H/dotfiles/.config/pi/agent/settings.json"
	"$H/dotfiles/.config/sandbox"
	"$H/dotfiles/.config/renv"
	"$H/dotfiles/.config/git/hooks"
	"$H/dotfiles/.local/scripts"
)
