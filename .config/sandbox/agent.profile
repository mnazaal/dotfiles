# agent — shared base for coding-agent harnesses. Composes the generic `dev`
# profile from this same sandbox profile directory, plus the machinery-ro
# enforcement pins.
use dev
use machinery-ro

RO+=(
	"$H/.agents"    # AGENTS.md + shared skills
	"$H/.config"
	"$H/.local"     # user-installed bins/libs (cargo, go, …)
	"$H/org/roam"   # org-roam notes (read-only for agents)
	"$H/org/agenda" # org-agenda (read-only for agents)
	"$H/projects"   # sibling projects - cross-reference reads only
	"$H/dotfiles"   # stow symlink targets + agent config work
)
RW+=(
	"$H/.cache"                 # tool caches (bun, uv, pip, …)
	"$H/.local/share"           # uv python installs, bun packages, …
	"$H/.local/state/nvim"      # Neovim LSP logs/state for in-agent editors
	"$H/.local/state/headroom"  # Headroom MCP logs/state for in-agent editors
	"$H/org/agents"             # shared agent wiki (read-write)
)

