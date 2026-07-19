#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"

make PREFIX="$PREFIX"
make PREFIX="$PREFIX" install
