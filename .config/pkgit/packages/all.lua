local lib = require("lib")

local cc = lib.cmake({ ccache = true })
local meson = lib.meson()
local meson_clean = lib.meson({ clean_root_build = true })

local local_pkg_config = prefix .. "/lib/x86_64-linux-gnu/pkgconfig:" .. prefix .. "/lib/pkgconfig:" .. prefix .. "/share/pkgconfig"

return {
  babl = { url = "https://gitlab.gnome.org/GNOME/babl.git", targets = meson },
  ccache = {
    url = "https://github.com/ccache/ccache.git",
    targets = lib.cmake({ flags = { "-DCMAKE_INSTALL_SYSCONFDIR=etc", "-DDEPS=AUTO", "-DENABLE_TESTING=OFF" } }),
  },
  dunst = { url = "https://github.com/dunst-project/dunst.git", targets = lib.make_prefix() },
  emacs = {
    url = "git://git.git.savannah.gnu.org/emacs.git",
    targets = lib.autotools({
      autogen = true,
      parallel = true,
      configure_flags = {
        "--with-pgtk",
        "--with-native-compilation=aot",
        "--with-tree-sitter",
        "--with-sqlite3",
        "--with-cairo",
        "--with-rsvg",
        "--with-modules",
        "--with-xml2",
        "--with-gnutls",
        "--with-mailutils",
      },
    }),
  },
  fastfetch = {
    url = "https://github.com/fastfetch-cli/fastfetch.git",
    targets = lib.cmake({ ccache = true, flags = { "-DENABLE_VULKAN=OFF", "-DCMAKE_INSTALL_SYSCONFDIR=etc" } }),
  },
  ["fish-shell"] = { url = "https://github.com/fish-shell/fish-shell.git", targets = cc },
  fzf = {
    url = "https://github.com/junegunn/fzf.git",
    targets = lib.target({
      build = function() return lib.sh("make install") end,
      install = function() return lib.install_bin("bin/fzf", "fzf") end,
    }),
  },
  gegl = {
    url = "https://gitlab.gnome.org/GNOME/gegl.git",
    targets = lib.target({
      build = function()
        local env = "cc_triplet=$(cc -dumpmachine 2>/dev/null || true); " ..
          "PKG_CONFIG_PATH=" .. lib.q(prefix .. "/share/pkgconfig:" .. prefix .. "/lib/pkgconfig") .. ":${cc_triplet:+" .. lib.q(prefix .. "/lib") .. "/$cc_triplet/pkgconfig:}${PKG_CONFIG_PATH:-}; " ..
          "LD_LIBRARY_PATH=${cc_triplet:+" .. lib.q(prefix .. "/lib") .. "/$cc_triplet:}" .. lib.q(prefix .. "/lib") .. ":${LD_LIBRARY_PATH:-}; " ..
          "export PKG_CONFIG_PATH LD_LIBRARY_PATH; "
        return lib.sh(env .. "meson setup build --prefix=" .. lib.q(prefix) .. " --reconfigure && ninja -C build")
      end,
      install = function() return lib.sh("ninja -C build install") end,
    }),
  },
  gimp = { url = "https://gitlab.gnome.org/GNOME/gimp.git", targets = meson },
  goose = {
    url = "https://github.com/aaif-goose/goose.git",
    targets = lib.target({
      build = function() return 0 end,
      install = function() return lib.sh("cargo install --force --locked --path crates/goose-cli --bin goose --root " .. lib.q(prefix)) end,
    }),
  },
  grim = { url = "https://gitlab.freedesktop.org/emersion/grim.git", targets = meson },
  ["isync-isync"] = { url = "https://git.code.sf.net/p/isync/isync", targets = lib.autotools({ autogen = true }) },
  keyd = { url = "https://github.com/rvaiya/keyd", targets = lib.make_prefix() },
  kitty = {
    url = "https://github.com/kovidgoyal/kitty.git",
    targets = lib.target({
      build = function() return lib.sh("./dev.sh build") end,
      install = function() return 0 end,
    }),
  },
  libinput = { url = "https://gitlab.freedesktop.org/libinput/libinput", targets = meson },
  ["llama.cpp"] = { url = "https://github.com/ggml-org/llama.cpp", targets = cc },
  mango = { url = "https://github.com/mangowm/mango.git", targets = meson_clean },
  ["nautilus-dropbox"] = { url = "https://github.com/dropbox/nautilus-dropbox.git", targets = lib.autotools({ autogen = true }) },
  neovim = {
    url = "https://github.com/neovim/neovim.git",
    targets = lib.target({
      build = function() return 0 end,
      install = function() return lib.sh("make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX=" .. lib.q(prefix) .. " install") end,
    }),
  },
  notmuch = { url = "https://github.com/notmuch/notmuch.git", targets = lib.autotools() },
  ["pass-otp"] = { url = "https://github.com/tadfisher/pass-otp", targets = lib.make_prefix() },
  pdfpc = { url = "https://github.com/pdfpc/pdfpc.git", targets = cc },
  pixman = { url = "https://gitlab.freedesktop.org/pixman/pixman.git", targets = meson },
  pwvucontrol = {
    url = "https://github.com/saivert/pwvucontrol.git",
    targets = lib.meson({ pkg_config_path = local_pkg_config, flags = { "--pkg-config-path=" .. local_pkg_config } }),
  },
  qpdf = { url = "https://github.com/qpdf/qpdf.git", targets = cc },
  rdfind = { url = "https://github.com/pauldreik/rdfind.git", targets = lib.autotools() },
  rofi = { url = "https://github.com/davatorium/rofi.git", targets = meson },
  scenefx = { url = "https://github.com/wlrfx/scenefx.git", targets = meson_clean },
  sioyek = {
    url = "https://github.com/ahrm/sioyek",
    targets = lib.target({
      build = function()
        return lib.sh(
          "set -e\nBIN=" .. lib.q(prefix .. "/bin") .. "\n" ..
          [==[
QT_VERSION="${QT_VERSION:-6.8.2}"
QT_ARCH="${QT_ARCH:-gcc_64}"
find_qmake() {
  if [ -n "${QMAKE:-}" ]; then printf '%s\n' "$QMAKE"; return 0; fi
  for candidate in \
    "$HOME/.local/src/qt/$QT_VERSION/$QT_ARCH/bin/qmake" \
    "$HOME/Qt/$QT_VERSION/$QT_ARCH/bin/qmake" \
    "$HOME/.local/opt/qt/$QT_VERSION/$QT_ARCH/bin/qmake" \
    "$HOME/.local/share/aqt/Qt/$QT_VERSION/$QT_ARCH/bin/qmake"; do
    [ -x "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
  done
  command -v qmake6 || command -v qmake
}
QMAKE=$(find_qmake)
version=$("$QMAKE" --version) || { echo "sioyek: qmake not found; install Qt 6.7 or 6.8" >&2; exit 1; }
case "$version" in
  *"Qt version 6.7"*|*"Qt version 6.8"*) : ;;
  *) printf 'sioyek: needs Qt 6.7 or 6.8 qmake\n%s\n' "$version" >&2; exit 1 ;;
esac
git submodule update --init --recursive
make distclean >/dev/null 2>&1 || make clean >/dev/null 2>&1 || true
QMAKE="$QMAKE" ./build_linux.sh
qt_prefix=$(realpath "$(dirname "$QMAKE")/..")
case "$qt_prefix" in
  "$HOME"/*) : ;;
  *) echo "sioyek: qt_prefix outside HOME — refusing wrapper: $qt_prefix" >&2; exit 1 ;;
esac
sioyek_build=$(realpath "$PWD/build/sioyek")
mkdir -p "$BIN"
cat > "$BIN/sioyek" <<WRAP
#!/usr/bin/env sh
export LD_LIBRARY_PATH="$qt_prefix/lib:\${LD_LIBRARY_PATH:-}"
export QT_PLUGIN_PATH="$qt_prefix/plugins\${QT_PLUGIN_PATH:+:\$QT_PLUGIN_PATH}"
exec "$sioyek_build" "\$@"
WRAP
chmod +x "$BIN/sioyek"
]==]
        )
      end,
      install = function() return 0 end,
    }),
  },
  slurp = { url = "https://github.com/emersion/slurp", targets = meson },
  stow = { url = "https://git.savannah.gnu.org/git/stow.git", targets = lib.autotools({ bootstrap = true }) },
  swaybg = { url = "https://github.com/swaywm/swaybg.git", targets = meson },
  swayidle = { url = "https://github.com/swaywm/swayidle.git", targets = lib.meson({ clean_root_build = true, flags = { "-Dbash-completions=false" } }) },
  swaylock = { url = "https://github.com/swaywm/swaylock.git", targets = lib.meson({ clean_root_build = true, flags = { "-Dbash-completions=false" } }) },
  waybar = { url = "https://github.com/Alexays/Waybar", targets = lib.meson({ flags = { "-Dsystemd=disabled" } }) },
  wayland = { url = "https://gitlab.freedesktop.org/wayland/wayland.git", version = "1.25.0", targets = lib.meson({ clean_root_build = true, flags = { "-Ddocumentation=false" } }) },
  ["wayland-protocols"] = { url = "https://gitlab.freedesktop.org/wayland/wayland-protocols.git", version = "1.48", targets = lib.meson({ clean_root_build = true, clean_unwritable_log = true }) },
  wireplumber = { url = "https://github.com/PipeWire/wireplumber.git", targets = meson },
  wlroots = { url = "https://gitlab.freedesktop.org/wlroots/wlroots.git", targets = meson_clean },
}
