# pkgit source package config

This directory configures pkgit source builds.

## Rules

- `pkgit` checkouts live in pkgit's configured source dir:
  `~/.local/share/pkgit`.
- pkgit installs into `${PREFIX:-$HOME/.local}`.
- pkgit recipes must not call unrelated source-build tooling.
- No machine-toggle profiles yet; this machine's current exact package list is
  declared here.

## Name normalization

Versioned source package names are normalized to pkgit-native package names:

| source package | pkgit package | recipe `checkout` |
|--------------|---------------|---------------|
| `wayland-1.25.0` | `wayland` | `1.25.0` |
| `wayland-protocols-1.48` | `wayland-protocols` | `1.48` |

The third column is the recipe's own `checkout` option, not pkgit's per-package
`version` field. That field is a no-op in the installed binary — it always
clones ref HEAD — so every pin in this config is a `checkout`.

## Current recipe groups

| Group | Packages |
|-------|----------|
| Meson | `babl`, `grim`, `libinput`, `pixman`, `rofi`, `slurp`, `swaybg`, `wireplumber` |
| Meson + flags/env | `gegl`, `gimp`, `pwvucontrol`, `waybar` |
| Meson, Wayland stack (root-build cleanup, pinned checkouts, prefix pkgconfig) | `libdisplay-info`, `libdrm`, `mango`, `scenefx`, `swayidle`, `swaylock`, `wayland`, `wayland-protocols`, `wlroots`, `xkbcommon` |
| CMake | `ccache`, `fastfetch`, `fish-shell`, `llama.cpp`, `pdfpc`, `qpdf` |
| Make + PREFIX | `dunst`, `keyd`, `pass-otp` |
| Autotools | `emacs`, `isync-isync`, `msmtp`, `nautilus-dropbox`, `notmuch`, `rdfind`, `stow` |
| Custom | `fzf`, `goose`, `kitty`, `neovim`, `sioyek` |

## Verification

No fake static checker. Real verification is package-by-package install through
pkgit after stowing this config.

For each package:

1. Run `pkgit -i <pkgit-name>` after stowing this config.
2. Check installed binary/library behavior under `~/.local`.
3. Mark the package as pkgit-verified in commit notes or another tracking file.

## Commands

- install: `pkgit -i <pkgit-name>`
- update: `pkgit -b <pkgit-name>,update`

`update` is a target profile defined in `lib.lua`, applied to every recipe. It
fetches, fast-forwards, rebuilds and installs in place.

**Never run `pkgit -u` or `pkgit -f`.** Both delete a package's source dir while
pkgit's own working directory is inside it; the clone that follows then fails on
`getcwd()`, leaving a checkout with no worktree files that `pkgit -i` refuses to
repair (it reports "already installed"). Recovery is
`rm -rf ~/.local/share/pkgit/<pkg> && pkgit -i <pkg>`.

pkgit exits 0 even when a build fails, so never chain it with `&&`; check the
installed artifact instead.

**`pkgit -r` does not run the recipe's uninstall.** In 1.2.0 its `repo_uninstall`
never loads the `repositories` table (`src/pkg_remove.c` omits the
`lua_getglobal` that the build and update paths do), logs
`init.lua: 'repositories' is not a table`, and falls through to a fallback that
matches a marker file in the source tree against the `build_systems` keys and
runs THAT entry's uninstall — then reports `[SUCCESS]` either way. So a removal
runs the bare `lib.make_prefix()`/`lib.meson()`/`lib.cmake()` uninstall with none
of the recipe's options: `pass-otp` without `BASHCOMPDIR`, `nautilus-dropbox`
without `NAUTILUS_EXTENSION_DIR`, the Wayland-stack packages without their prefix
pkgconfig. It also picks by table order when a tree carries two markers (`neovim`
has both a `Makefile` and a `CMakeLists.txt`), so which one runs is not
determined. Uninstall by hand instead; writing per-recipe `uninstall` functions
would not help, because nothing calls them.

## Update semantics

pkgit source checkouts are disposable build trees. The pkgit build wrapper
fetches the tracked branch explicitly before each build and then:

- fast-forward when possible;
- auto-reset a clean checkout when upstream rebased or force-pushed;
- discard local changes to tracked files first, because an autotools bootstrap
  rewrites tracked files it does not own (stow's `aclocal.m4`, rdfind's
  `INSTALL`, msmtp's `po/*`) and refusing would let one build block every later
  update. Untracked files, `build/` included, are left alone;
- skip the source update on a detached HEAD (a `checkout` pin), and refuse
  outright when a Git operation is already in progress.

Do not use pkgit checkouts for local development unless you first move the work
elsewhere; pkgit source-package trees are allowed to be reset to upstream.
