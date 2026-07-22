#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"

# Upstream run.sh builds and runs fastfetch, but does not install and does not
# set CMAKE_INSTALL_PREFIX. Configure directly so install stays under PREFIX.
cmake -S . -B build \
	-DENABLE_VULKAN=OFF \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$PREFIX" \
	-DCMAKE_INSTALL_SYSCONFDIR=etc \
	-DCMAKE_C_COMPILER_LAUNCHER=ccache \
	-DCMAKE_CXX_COMPILER_LAUNCHER=ccache
cmake --build build
cmake --install build
