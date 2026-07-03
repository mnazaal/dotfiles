#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"


meson setup build --prefix="$PREFIX" --reconfigure
ninja -C build
ninja -C build install
