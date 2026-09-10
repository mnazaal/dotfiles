# dev — make common developer toolchains visible (read-only) under the strict
# home-tmpfs, so language tools resolve. Compose with: sandbox -p dev -- npm test
RO+=(
	"$H/.local/bin"
	# Load-bearing for a standalone `dev` sandbox only: under the tmpfs home this
	# is what makes the fnm tree visible at all. It is NOT a write guard under
	# `agent`, whose blanket read-write $H/.local/share is emitted later and
	# wins; the pin that actually holds there is machinery-ro.profile's RO_LAST
	# entry for the same path (shadowing measured 2026-09-09).
	"$H/.local/share/fnm"
	"$H/.local/share/bun"
	"$H/.config/git"
)

# The PATH usually points at an ephemeral fnm shim that won't exist in the
# sandbox; resolve the real node bin dir and prepend the toolchain bins.
if _np=$(command -v node 2>/dev/null); then
	_nb=$(dirname "$(readlink -f "$_np")")
	# RO_LAST, not RO: this directory is prepended to the sandbox PATH below, and
	# a plain read-only bind is emitted BEFORE agent.profile's blanket read-write
	# $H/.local/share, which contains it and therefore wins. Measured 2026-09-06 —
	# a file written here from inside reached the host, in the directory holding
	# the node binary that every later out-of-sandbox session runs. Same hazard
	# machinery-ro.profile pins the bun bin dir against.
	RO_LAST+=("$_nb")
	SANDBOX_PATH_PREPEND="$H/.local/bin:$H/.local/share/bun/bin:$_nb"
fi
