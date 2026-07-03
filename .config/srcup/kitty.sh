#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"


# Use upstream development wrapper so vendored dependencies are available.
./dev.sh build
