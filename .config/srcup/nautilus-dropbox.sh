#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"


./autogen.sh
./configure --prefix="$PREFIX"
make
make install
