#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"

prepend_path_var() {
	local var="$1"
	local dir="$2"
	local current="${!var-}"

	[[ -d "$dir" ]] || return 0
	case ":$current:" in
	*":$dir:"*) ;;
	*) export "$var=$dir${current:+:$current}" ;;
	esac
}

cc_triplet=$(cc -dumpmachine 2>/dev/null || true)

prepend_path_var PKG_CONFIG_PATH "$PREFIX/share/pkgconfig"
prepend_path_var PKG_CONFIG_PATH "$PREFIX/lib/pkgconfig"
if [[ -n "$cc_triplet" ]]; then
	prepend_path_var PKG_CONFIG_PATH "$PREFIX/lib/$cc_triplet/pkgconfig"
	prepend_path_var LD_LIBRARY_PATH "$PREFIX/lib/$cc_triplet"
fi
prepend_path_var LD_LIBRARY_PATH "$PREFIX/lib"

meson setup build --prefix="$PREFIX" --reconfigure
ninja -C build
ninja -C build install
