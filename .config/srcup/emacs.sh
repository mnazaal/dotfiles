#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
JOBS="${JOBS:-$(nproc)}"


./autogen.sh
./configure \
	--prefix="$PREFIX" \
	--with-pgtk \
	--with-native-compilation=aot \
	--with-tree-sitter \
	--with-sqlite3 \
	--with-cairo \
	--with-rsvg \
	--with-modules \
	--with-xml2 \
	--with-gnutls \
	--with-mailutils
make -j"$JOBS"
make install
