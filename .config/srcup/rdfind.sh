#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"

./configure --prefix="$PREFIX"
make
make install
