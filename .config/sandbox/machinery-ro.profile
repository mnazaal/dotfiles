# machinery-ro — OS-level write protection for the agent enforcement stack.
# Compose from EVERY agent-* profile.
#
# RO_LAST binds are emitted after every RW bind, including the auto-bound
# read-write $PWD. The plain read-only binds on $H/.agents and $H/.config do
# not protect these paths: both trees are stow symlinks whose targets live
# under $H/dotfiles, so a harness launched with cwd=~/dotfiles could otherwise
# rewrite its own guardrails, hooks, or this sandbox script by writing the
# symlink target. Editing machinery is a deliberate out-of-sandbox action.
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
	"$H/dotfiles/.local/share/gnupg/gpg-agent.conf"
  # "$H/dotfiles/.agents/skills"
	# Shell-startup files (machinery tier in sensitive-paths.json): hijacking
	# one persists across sessions outside any sandbox.
	"$H/dotfiles/.config/zsh"
	"$H/dotfiles/.zshenv"
	"$H/dotfiles/.bashrc"
	"$H/dotfiles/.bash_profile"
	# Writable dirs on SANDBOX_PATH_PREPEND are a cross-session persistence
	# vector: agent.profile's blanket RW ~/.local/share shadows dev's read-only
	# bun bind, leaving the bun bin dir writable AND on PATH. Pin it.
	"$H/.local/share/bun/bin"
)
