#!/usr/bin/env bash
# The pi shim is the only thing between typing `pi` and an unconfined agent, so
# assert the wrapper it builds, the key it resolves, and every path that must
# refuse rather than launch bare. Replaces the renv coverage this shim retired.
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
shim="$repo/.local/scripts/pi"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin" bun="$tmp/bun" capture="$tmp/capture"
mkdir -p "$bin" "$bun/bin"

cat >"$bin/pass" <<'EOF'
#!/usr/bin/env bash
[ "$1" = show ] || exit 1
printf '%s\n' "secret-$2"
EOF
# Stands in for the real launcher: records the environment that crossed and the
# argv it was handed, which is the whole contract under test.
cat >"$bin/sandbox" <<EOF
#!/usr/bin/env bash
printf 'asta=%s\n' "\${ASTA_MCP_API_KEY:-}" >"$capture"
printf '%s\n' "\$@" >>"$capture"
EOF
cat >"$bun/bin/pi" <<'EOF'
#!/usr/bin/env bash
printf 'real-pi-ran %s\n' "$*"
EOF
chmod +x "$bin"/* "$bun/bin/pi"

run_shim() { # args... -> shim stdout; sandbox argv lands in $capture
	rm -f "$capture"
	env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME \
		PATH="$bin:$PATH" BUN_INSTALL="$bun" "$shim" "$@"
}

expect() { # label haystack needle
	case "$2" in *"$3"*) ;; *)
		printf 'pi shim %s: expected %s in\n%s\n' "$1" "$3" "$2" >&2
		exit 1
		;;
	esac
}

refuses() { # label -> non-zero exit AND the sandbox never reached
	rm -f "$capture"
	if "$@" >/dev/null 2>&1; then
		printf 'pi shim %s: launched anyway\n' "$1" >&2
		exit 1
	fi
	[ ! -e "$capture" ] || {
		printf 'pi shim %s: reached the sandbox\n' "$1" >&2
		exit 1
	}
}

# --- the wrapper it builds ---------------------------------------------------
# The real binary must be named ABSOLUTELY: this shim shadows `pi` on PATH, so a
# lookup would find the shim and re-exec it forever.
run_shim --version >/dev/null
args=$(<"$capture")
expect 'resolves the key outside the boundary' "$args" 'asta=secret-asta-mcp'
expect 'selects the pi profile' "$args" $'-p\nagent-pi'
expect 'runs the real binary absolutely' "$args" "$bun/bin/pi"
expect 'passes arguments through' "$args" '--version'

# --- fail closed -------------------------------------------------------------
# Each of these leaves "run pi with no boundary" as the only alternative.
mv "$bin/sandbox" "$tmp/sandbox.hidden"
refuses 'without a sandbox on PATH' env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME \
	PATH="$bin:$PATH" BUN_INSTALL="$bun" "$shim" --version
mv "$tmp/sandbox.hidden" "$bin/sandbox"

printf '#!/usr/bin/env bash\nexit 1\n' >"$bin/pass"
chmod +x "$bin/pass"
refuses 'when the key cannot be read' env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME \
	PATH="$bin:$PATH" BUN_INSTALL="$bun" "$shim" --version
cat >"$bin/pass" <<'EOF'
#!/usr/bin/env bash
[ "$1" = show ] || exit 1
printf '%s\n' "secret-$2"
EOF
chmod +x "$bin/pass"

refuses 'when the real binary is missing' env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME \
	PATH="$bin:$PATH" BUN_INSTALL="$tmp/absent" "$shim" --version

# --- already inside a boundary ----------------------------------------------
# Nesting a second bubblewrap fails, and the outer sandbox already confines the
# process, so the shim must step aside rather than wrap again.
rm -f "$capture"
out=$(env -u SANDBOX_RUNTIME SANDBOX_ENGINE=bwrap \
	PATH="$bin:$PATH" BUN_INSTALL="$bun" "$shim" --version)
expect 'runs the real binary directly when sandboxed' "$out" 'real-pi-ran --version'
[ ! -e "$capture" ] || {
	printf 'pi shim: nested a second sandbox inside the first\n' >&2
	exit 1
}

printf 'pi shim: all behaviors pass\n'
