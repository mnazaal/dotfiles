#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"


# Upstream ./install writes to ~/.fzf and may edit shell config.
# Makefile install target only builds bin/fzf, so use it then copy into PREFIX.
make install
install -Dm755 bin/fzf "$PREFIX/bin/fzf"
