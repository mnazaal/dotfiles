#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
LOCAL_PKG_CONFIG_PATH="$PREFIX/lib/x86_64-linux-gnu/pkgconfig:$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"

export PKG_CONFIG_PATH="$LOCAL_PKG_CONFIG_PATH:${PKG_CONFIG_PATH:-}"

meson setup build --prefix="$PREFIX" --pkg-config-path="$LOCAL_PKG_CONFIG_PATH" --reconfigure
ninja -C build
ninja -C build install
