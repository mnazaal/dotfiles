#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"


make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$PREFIX" install
