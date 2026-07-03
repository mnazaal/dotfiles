# sandbox

Run **any** command confined to an allowlist of directories. One profile/allowlist
front-end drives three backends; coding-agent harnesses are just one set of
profiles.

```sh
sandbox -- ./configure && make     # confined to the current project
sandbox -p dev -- npm test         # + dev toolchains (node/bun/git) read-only
sandbox --rw ~/scratch -- ./untrusted-installer.sh
sandbox --no-net -- python build.py
sandbox --backend podman -- id     # override the default backend
sandbox -n -- make                 # dry-run: print the backend command
```

## Model

Only an allowlist is visible. The current project (`$PWD`) is read-write; system
dirs and whatever the active profile adds are read-only; **everything else under
`$HOME` — `~/.ssh`, `~/.gnupg`, `~/.password-store`, other projects — is
invisible**. Secrets already in the environment pass through, so a caller (e.g.
`renv`) can resolve them *before* entering the sandbox; the vaults themselves are
never mounted.

How "invisible" is achieved depends on the backend: the container backends
(`gvisor`/`podman`) only mount the allowlist, so the rest of the host simply isn't
there; `bwrap` lays a tmpfs over `$HOME` and binds the allowlist back.

All backends provide a writable private `/tmp` for scratch files. Host `/tmp` is
not mounted; use `--rw DIR` for any explicit shared scratch directory.

Guards: `sandbox` refuses to auto-bind `cwd` when it is `$HOME` or above (which
would re-expose the whole home), and rejects `--rw`/`--ro` of `$HOME` or `/`.
Network is shared by default; `--no-net` cuts it.

## Backends

Select with `--backend` or `$SANDBOX_BACKEND`.

| Backend | Isolation | Needs | Notes |
|---------|-----------|-------|-------|
| **gvisor** (default) | host-kernel attack surface shrunk by a user-space kernel (runsc) | `runsc` on PATH (no root/KVM) | rootless container via `--runtime=runsc`; FS served through a gofer (a bit slower) |
| **podman** | namespaces (shared kernel) | rootless podman | same container, default runtime; lighter than gvisor |
| **bwrap** | namespaces (shared kernel) | bubblewrap; on Ubuntu the one-time `sandbox --init ubuntu` | binds host rootfs directly; lightest start-up |

The container backends reuse the host userspace through read-only mounts (`/usr`,
toolchains), an `ubuntu:24.04` base image (`$SANDBOX_IMAGE`), `--userns=keep-id`,
and `--network=host`. They need no root. `bwrap` is the fallback for hosts where
you *do* have root and want the lightest option.

## Profiles

A profile is a tiny `*.profile` file sourced by the engine; it appends to the
`RW` / `RO` / `RW_FILES` / `RO_FILES` arrays and can `use NAME` to compose
another. `-p NAME` resolves a bare name against **`$SANDBOX_PROFILE_PATH`**
(default `~/.config/sandbox`); `-p PATH` (containing `/`) loads a file directly.

Profiles live in `~/.config/sandbox` so direct sandbox invocations and `renv`
harnesses use the same profile namespace:

| Profile | Where | Adds |
|---------|-------|------|
| `dev` | `~/.config/sandbox/` | node/bun/fnm toolchains, `~/.gitconfig` (ro) + PATH fixup |
| `agent` | `~/.config/sandbox/` | `use dev` + `~/dotfiles`, `~/.agents` (ro) + `~/org/agents` (rw) |
| `agent-claude` / `agent-opencode` / `agent-pi` | `~/.config/sandbox/` | `use agent` + that harness's state |

## Coding agents (via renv)

The harness env files (`~/.config/renv/{claude,opencode,pi}.sh`) own the sandbox
decision — `renv` knows nothing about it. They set
`RENV_WRAP=(sandbox -p agent-<cmd> --)`; `renv` then runs the harness under that
wrapper (a generic feature — an env file may set `RENV_WRAP` to any prefix
command). Comment that line out to disable. Fails closed: if the wrapper errors,
the harness never launches unconfined.

```sh
renv claude         # launches confined (default backend), no extra steps
```

## One-time setup

- **gvisor**: install `runsc` (single userspace binary, no root/KVM) →
  <https://gvisor.dev/docs/user_guide/install/>. `sandbox` errors with this
  pointer if it's missing.
- **podman**: nothing — rootless podman works out of the box.
- **bwrap**: `sandbox --init ubuntu` once (self-elevates with sudo; installs the
  AppArmor profile from `~/.local/share/sandbox/`). Only needed for `--backend bwrap`.

## Limits / caveats

- `--network=host`: the agent shares the host network (localhost services, the
  internal network). Convenient for in-the-loop use; not network isolation.
- `--env-host`: the whole environment is passed in. `renv` only *sets* the
  specific keys the harness needs, but the transport is bulk — other exported
  vars ride along.
- No resource caps by default (a too-tight `--memory`/`--pids-limit` would kill an
  interactive agent mid-task; add them only for unattended runs).
- `~/.ssh` / `pass` are absent inside, so `git push` over SSH and `pass` reads
  won't work in the sandbox — do those outside, or pass a token via env.
- Shared kernel for `podman`/`bwrap`; `gvisor` re-implements the kernel in user
  space for stronger escape resistance. A microVM (KVM) would be stronger still
  but the host gates `/dev/kvm`.
