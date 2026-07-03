#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"


# Purge stale root-owned build artifacts from prior sudo installs
if [[ -f build/.ninja_deps ]] && [[ "$(stat -c %U build/.ninja_deps)" == "root" ]]; then
	rm -rf build
fi

meson setup build --prefix="$PREFIX" --reconfigure -Dbash-completions=false
ninja -C build
ninja -C build install
