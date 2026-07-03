#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"


cmake -S . -B build \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$PREFIX" \
	-DCMAKE_INSTALL_SYSCONFDIR=etc \
	-DDEPS=AUTO \
	-DENABLE_TESTING=OFF
cmake --build build
cmake --install build
