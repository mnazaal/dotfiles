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

| source package | pkgit package | pkgit version |
|--------------|---------------|---------------|
| `wayland-1.25.0` | `wayland` | `1.25.0` |
| `wayland-protocols-1.48` | `wayland-protocols` | `1.48` |

## Current recipe groups

| Group | Packages |
|-------|----------|
| Meson | `babl`, `gimp`, `grim`, `libinput`, `pixman`, `rofi`, `slurp`, `swaybg`, `wireplumber` |
| Meson + cleanup | `mango`, `scenefx`, `wlroots` |
| Meson + flags | `swayidle`, `swaylock`, `waybar`, `wayland`, `wayland-protocols`, `pwvucontrol` |
| CMake | `ccache`, `fastfetch`, `fish-shell`, `llama.cpp`, `pdfpc`, `qpdf` |
| Make + PREFIX | `dunst`, `keyd`, `pass-otp` |
| Autotools | `isync-isync`, `nautilus-dropbox`, `notmuch`, `rdfind`, `stow`, `emacs` |
| Custom | `fzf`, `goose`, `kitty`, `neovim`, `sioyek`, `gegl` |

## Verification

No fake static checker. Real verification is package-by-package install through
pkgit after stowing this config.

For each package:

1. Run `pkgit -i <pkgit-name>` after stowing this config.
2. Check installed binary/library behavior under `~/.local`.
3. Mark the package as pkgit-verified in commit notes or another tracking file.

## Update semantics

pkgit source checkouts are disposable build trees. The pkgit build wrapper
fetches the tracked branch explicitly before each build and then:

- fast-forward when possible;
- auto-reset a clean checkout when upstream rebased or force-pushed;
- refuse to update dirty worktrees, detached HEADs, or repos with an in-progress
  Git operation.

Do not use pkgit checkouts for local development unless you first move the work
elsewhere; pkgit source-package trees are allowed to be reset to upstream.
