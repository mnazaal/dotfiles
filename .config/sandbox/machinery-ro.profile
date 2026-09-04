# machinery-ro — OS-level protection the sandbox applies for every harness.
# Two tiers, both enforced by the kernel rather than by any harness's hook:
# RO_LAST pins the agent enforcement stack against writes, and MASK hides host
# credential stores from reads entirely. Compose from EVERY agent-* profile.
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

# Host secrets that a broad read-write bind would otherwise hand over. .zshenv
# relocates the GnuPG keyring and the password store under $H/.local/share, and
# the mail store lives there too; agent.profile binds that whole directory
# read-write for uv/bun/cargo, so all three arrived writable. A read-only pin
# would only stop tampering — the encrypted store, the keyring and every mail
# file would stay readable, and a warm gpg-agent socket would still decrypt. An
# empty tmpfs makes them absent instead, which is what the never-bound stores
# already get. Lives here, not in agent.profile, because agent.profile is
# composed by agent-claude alone: a harness that later grows a broad bind must
# inherit this without a second edit.
MASK+=(
	"$H/.local/share/gnupg"
	"$H/.local/share/pass"
	"$H/.local/share/password-store"
	"$H/.local/share/keyrings"
	"$H/.local/share/mail"
	"$H/.local/share/zsh"
)
