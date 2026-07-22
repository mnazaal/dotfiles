#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"

cargo install --force --locked --path crates/goose-cli --bin goose --root "$PREFIX"
