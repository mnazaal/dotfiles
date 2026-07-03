# dev — make common developer toolchains visible (read-only) under the strict
# home-tmpfs, so language tools resolve. Compose with: sandbox -p dev -- npm test
RO+=(
	"$H/.local/bin"
	"$H/.local/share/fnm"
	"$H/.local/share/bun"
	"$H/.gitconfig"
	"$H/.config/git"
)

# The PATH usually points at an ephemeral fnm shim that won't exist in the
# sandbox; resolve the real node bin dir and prepend the toolchain bins.
if _np=$(command -v node 2>/dev/null); then
	_nb=$(dirname "$(readlink -f "$_np")")
	RO+=("$_nb")
	SANDBOX_PATH_PREPEND="$H/.local/bin:$H/.local/share/bun/bin:$_nb"
fi
