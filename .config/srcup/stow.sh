#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"

./bootstrap
./configure --prefix="$PREFIX"
make
make install
