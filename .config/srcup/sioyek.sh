#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
QT_VERSION="${QT_VERSION:-6.8.2}"
QT_ARCH="${QT_ARCH:-gcc_64}"

find_qmake() {
	if [[ -n "${QMAKE:-}" ]]; then
		printf '%s\n' "$QMAKE"
		return 0
	fi

	local candidate
	for candidate in \
		"$HOME/.local/src/qt/$QT_VERSION/$QT_ARCH/bin/qmake" \
		"$HOME/Qt/$QT_VERSION/$QT_ARCH/bin/qmake" \
		"$HOME/.local/opt/qt/$QT_VERSION/$QT_ARCH/bin/qmake" \
		"$HOME/.local/share/aqt/Qt/$QT_VERSION/$QT_ARCH/bin/qmake"; do
		if [[ -x "$candidate" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	command -v qmake
}

require_supported_qmake() {
	local version
	version=$("$QMAKE" --version) || {
		echo "sioyek: qmake not found; install Qt and ensure qmake is in PATH" >&2
		exit 1
	}

	if [[ "$version" != *"Qt version 6.7"* && "$version" != *"Qt version 6.8"* ]]; then
		printf 'sioyek: development branch needs Qt 6.7 or 6.8 qmake\n%s\n' "$version" >&2
		exit 1
	fi
}

update_repo() {
	git submodule update --init --recursive
}

build_sioyek() {
	make distclean >/dev/null 2>&1 || make clean >/dev/null 2>&1 || true
	QMAKE="$QMAKE" ./build_linux.sh
}

install_wrapper() {
	local qt_prefix sioyek_build
	qt_prefix=$(realpath "$(dirname "$QMAKE")/..")
	sioyek_build=$(realpath "$PWD/build/sioyek")

	# Validate qt_prefix is under an expected Qt install tree
	if [[ "$qt_prefix" != "$HOME"/* ]]; then
		echo "sioyek: qt_prefix outside HOME — refusing to generate wrapper: $qt_prefix" >&2
		exit 1
	fi

	mkdir -p "$PREFIX/bin"
	cat >"$PREFIX/bin/sioyek" <<EOF
#!/usr/bin/env sh
export LD_LIBRARY_PATH="$qt_prefix/lib:\${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="$qt_prefix/plugins\${QT_PLUGIN_PATH:+:\$QT_PLUGIN_PATH}"
exec "$sioyek_build" "\$@"
EOF
	chmod +x "$PREFIX/bin/sioyek"
}

QMAKE=$(find_qmake)
require_supported_qmake
update_repo
build_sioyek
install_wrapper
