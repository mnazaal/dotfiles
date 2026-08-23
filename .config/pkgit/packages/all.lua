local lib = require("lib")

local cc = lib.cmake({ ccache = true })
local meson = lib.meson()

local local_pkg_config = prefix .. "/lib/x86_64-linux-gnu/pkgconfig:" .. prefix .. "/lib/pkgconfig:" .. prefix .. "/share/pkgconfig"

local repos = {
  babl = { url = "https://gitlab.gnome.org/GNOME/babl.git", targets = meson },
  ccache = {
    url = "https://github.com/ccache/ccache.git",
    targets = lib.cmake({ flags = { "-DCMAKE_INSTALL_SYSCONFDIR=etc", "-DDEPS=AUTO", "-DENABLE_TESTING=OFF" } }),
  },
  dunst = { url = "https://github.com/dunst-project/dunst.git", targets = lib.make_prefix() },
  emacs = {
    url = "https://git.savannah.gnu.org/git/emacs.git",
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
  -- gegl needs the prefix babl at build time (pkgconfig) and its in-tree tools
  -- dlopen prefix libs at run time — the same two needs gimp has, so it takes
  -- the same M.meson options. This was hand-rolled only for the build env,
  -- which M.meson has carried since the `env` option landed. The multiarch dir
  -- is written out rather than derived from `cc -dumpmachine`: babl-0.1.pc,
  -- gegl-0.4.pc and libgegl-0.4.so all sit under lib/x86_64-linux-gnu here,
  -- and a wrong guess fails loudly (meson cannot find babl), not silently.
  gegl = {
    url = "https://gitlab.gnome.org/GNOME/gegl.git",
    targets = lib.meson({
      pkg_config_path = local_pkg_config,
      env = { LD_LIBRARY_PATH = prefix .. "/lib/x86_64-linux-gnu:" .. prefix .. "/lib" },
    }),
  },
  -- gimp master is painful on a ~/.local stack under a minimal session (mango):
  --  (1) -Dvala=disabled: vapigen resolves Vala bindings via vapi/GIR dirs (from
  --      XDG_DATA_DIRS, which lacks ~/.local/share), not pkg-config, so it can't
  --      find the prefix gegl/babl vapi. Vala GIMP plugins are niche; skip them.
  --  (2) the build runs an in-tree gimp-console that does gi.require_version('Gegl')
  --      and dlopens prefix libgegl — needs GI_TYPELIB_PATH + LD_LIBRARY_PATH (+
  --      XDG_DATA_DIRS) at prefix. The user's normal shell exports these; mango's
  --      session doesn't, so pin them here to make the recipe session-independent.
  gimp = {
    url = "https://gitlab.gnome.org/GNOME/gimp.git",
    targets = lib.meson({
      pkg_config_path = local_pkg_config,
      flags = { "-Dvala=disabled" },
      env = {
        GI_TYPELIB_PATH = prefix .. "/lib/x86_64-linux-gnu/girepository-1.0:" .. prefix .. "/lib/girepository-1.0",
        LD_LIBRARY_PATH = prefix .. "/lib/x86_64-linux-gnu:" .. prefix .. "/lib",
        XDG_DATA_DIRS = prefix .. "/share",
      },
    }),
  },
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
  -- kitty runs from its build tree: the launcher locates the vendored python
  -- tree beside itself, so it is linked rather than copied. Without this the
  -- PATH entry stayed a hand-made symlink into ~/.local/src/kitty, i.e. the
  -- running terminal came from a tree pkgit does not own and deleting that
  -- tree would have broken it. `kitten` sits in the same directory if wanted.
  kitty = {
    url = "https://github.com/kovidgoyal/kitty.git",
    targets = lib.target({
      build = function() return lib.sh("./dev.sh build") end,
      install = function()
        return lib.sh(
          "[ -x kitty/launcher/kitty ] || { echo 'kitty: launcher missing after build' >&2; exit 1; }\n" ..
          "ln -sfn \"$(pwd)/kitty/launcher/kitty\" " .. lib.q(prefix .. "/bin/kitty")
        )
      end,
    }),
  },
  -- wlroots 0.20's drm-backend (needed to run on a TTY, not just nested) needs
  -- libdisplay-info >=0.2.0; Ubuntu 24.04 ships 0.1.1. Build it into prefix, then
  -- rebuild wlroots so drm-backend flips from NO to YES. Same floor-bump story.
  ["libdisplay-info"] = { url = "https://gitlab.freedesktop.org/emersion/libdisplay-info.git", targets = lib.meson({ clean_root_build = true, checkout = "0.2.0" }) },
  -- wlroots >=0.20 needs libdrm >=2.4.129; this host ships 2.4.125. Build a
  -- newer libdrm into prefix (core only: auto_features off) and let wlroots pick
  -- it up via local_pkg_config. Pinned to a release like wayland/wayland-protocols.
  libdrm = { url = "https://gitlab.freedesktop.org/mesa/drm.git", targets = lib.meson({ clean_root_build = true, checkout = "libdrm-2.4.134", flags = { "-Dauto_features=disabled", "-Dtests=false" } }) },
  libinput = { url = "https://gitlab.freedesktop.org/libinput/libinput", targets = meson },
  ["llama.cpp"] = { url = "https://github.com/ggml-org/llama.cpp", targets = cc },
  -- Compositor built on wlroots-0.20 + scenefx; needs their prefix pkgconfigs.
  -- mango main uses PANGO_WRAP_NONE (Pango >=1.56) in one spot (draw/text-node.c);
  -- Ubuntu 24.04 ships Pango 1.52, and building 1.56 would drag in glib>=2.82 +
  -- harfbuzz>=8.4 (shadowing system glib is too risky). Map the one enum use to
  -- the existing PANGO_WRAP_WORD_CHAR via a compiler define. Drop when the OS
  -- ships Pango >=1.56 (then the define would clash with the real enumerator).
  mango = { url = "https://github.com/mangowm/mango.git", targets = lib.meson({ clean_root_build = true, pkg_config_path = local_pkg_config, flags = { "-Dc_args=-DPANGO_WRAP_NONE=PANGO_WRAP_WORD_CHAR" } }) },
  -- Outbound mail for rss2email (and anything else needing sendmail): the
  -- tracked ~/.config/msmtp/config uses `eval` lines, which need msmtp >=1.8.20.
  msmtp = { url = "https://git.marlam.de/git/msmtp.git", targets = lib.autotools({ autoreconf = true }) },
  -- The nautilus extension .so installs to an ABSOLUTE system dir
  -- (NAUTILUS_EXTENSION_DIR=/usr/lib/.../nautilus/extensions-4) → EACCES on a
  -- ~/.local install (a plain `make install` fails here too). Redirect it
  -- under prefix so the whole install completes (incl. the `dropbox` CLI). For
  -- Nautilus to actually load it, set NAUTILUS_4_EXTENSION_DIR to that prefix dir.
  ["nautilus-dropbox"] = { url = "https://github.com/dropbox/nautilus-dropbox.git", targets = lib.autotools({ autogen = true, make_vars = { NAUTILUS_EXTENSION_DIR = prefix .. "/lib/x86_64-linux-gnu/nautilus/extensions-4" } }) },
  neovim = {
    url = "https://github.com/neovim/neovim.git",
    targets = lib.target({
      build = function() return 0 end,
      install = function() return lib.sh("make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX=" .. lib.q(prefix) .. " install") end,
    }),
  },
  notmuch = { url = "https://github.com/notmuch/notmuch.git", targets = lib.autotools() },
  ["pass-otp"] = {
    url = "https://github.com/tadfisher/pass-otp",
    targets = lib.make_prefix({ vars = { BASHCOMPDIR = prefix .. "/share/bash-completion/completions" } }),
  },
  pdfpc = { url = "https://github.com/pdfpc/pdfpc.git", targets = cc },
  pixman = { url = "https://gitlab.freedesktop.org/pixman/pixman.git", targets = meson },
  pwvucontrol = {
    url = "https://github.com/saivert/pwvucontrol.git",
    targets = lib.meson({ pkg_config_path = local_pkg_config, flags = { "--pkg-config-path=" .. local_pkg_config } }),
  },
  qpdf = { url = "https://github.com/qpdf/qpdf.git", targets = cc },
  rdfind = { url = "https://github.com/pauldreik/rdfind.git", targets = lib.autotools({ autoreconf = true }) },
  rofi = { url = "https://github.com/davatorium/rofi.git", targets = meson },
  -- scenefx 0.5 pins wlroots-0.20 (>=0.20.0 <0.21.0); needs the prefix
  -- wlroots-0.20.pc, so read local_pkg_config.
  scenefx = { url = "https://github.com/wlrfx/scenefx.git", targets = lib.meson({ clean_root_build = true, pkg_config_path = local_pkg_config }) },
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
# Remove first: $BIN/sioyek may still be an older symlink into ~/.local/src,
# and a bare redirect writes THROUGH a symlink — which once overwrote the
# binary at the other end with this wrapper.
rm -f "$BIN/sioyek"
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
  stow = { url = "https://git.savannah.gnu.org/git/stow.git", targets = lib.autotools({ autoreconf = true }) },
  swaybg = { url = "https://github.com/swaywm/swaybg.git", targets = meson },
  swayidle = { url = "https://github.com/swaywm/swayidle.git", targets = lib.meson({ clean_root_build = true, flags = { "-Dbash-completions=false" } }) },
  swaylock = { url = "https://github.com/swaywm/swaylock.git", targets = lib.meson({ clean_root_build = true, flags = { "-Dbash-completions=false" } }) },
  waybar = { url = "https://github.com/Alexays/Waybar", targets = lib.meson({ flags = { "-Dsystemd=disabled" } }) },
  wayland = { url = "https://gitlab.freedesktop.org/wayland/wayland.git", targets = lib.meson({ clean_root_build = true, checkout = "1.25.0", flags = { "-Ddocumentation=false" } }) },
  ["wayland-protocols"] = { url = "https://gitlab.freedesktop.org/wayland/wayland-protocols.git", targets = lib.meson({ clean_root_build = true, checkout = "1.48", clean_unwritable_log = true }) },
  wireplumber = { url = "https://github.com/PipeWire/wireplumber.git", targets = meson },
  -- Pin to 0.20.x: scenefx/mango require the wlroots-0.20 pkgconfig; HEAD is
  -- 0.21.0-dev. Reads local_pkg_config to find the prefix libdrm (>=2.4.129).
  wlroots = { url = "https://gitlab.freedesktop.org/wlroots/wlroots.git", targets = lib.meson({ clean_root_build = true, checkout = "0.20.2", pkg_config_path = local_pkg_config }) },
  -- wlroots 0.20 needs xkbcommon >=1.8.0; Ubuntu 24.04 ships 1.6.0 and this
  -- never built it (its older wlroots predated the floor). Core build only
  -- (docs/x11 off) into prefix. Same story as libdrm.
  -- enable-bash-completion installs xkbcli's completion to an ABSOLUTE system
  -- dir (/usr/share/bash-completion/completions) → sudo prompt on a ~/.local
  -- install; disable it (as swayidle/swaylock do). Everything else stays in prefix.
  xkbcommon = { url = "https://github.com/xkbcommon/libxkbcommon.git", targets = lib.meson({ clean_root_build = true, checkout = "xkbcommon-1.13.2", flags = { "-Denable-docs=false", "-Denable-x11=false", "-Denable-bash-completion=false" } }) },
}

-- pkgit validates a per-package `dependencies` table before building and logs
-- "init.lua: 'dependencies' is not a table" when it's absent. No inter-package
-- deps are declared (packages build in order), so default each to an empty table.
for _, spec in pairs(repos) do
  spec.dependencies = spec.dependencies or {}
end

return repos
