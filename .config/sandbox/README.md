# sandbox

Run **any** command confined to an allowlist of directories. One profile/allowlist
front-end drives two backends; coding-agent harnesses are just one set of
profiles.

```sh
sandbox -- ./configure && make     # confined to the current project
sandbox -p dev -- npm test         # + dev toolchains (node/bun/git) read-only
sandbox --rw ~/scratch -- ./untrusted-installer.sh
sandbox --no-net -- python build.py
sandbox -n -- make                 # dry-run: print the podman command
```

## Model

Only an allowlist is visible. The current project (`$PWD`) is read-write; system
dirs and whatever the active profile adds are read-only; **everything else under
`$HOME` — `~/.ssh`, `~/.gnupg`, `~/.password-store`, other projects — is
invisible**. Secrets already in the environment pass through, so a caller (e.g.
`renv`) can resolve them *before* entering the sandbox; the vaults themselves are
never mounted.

"Invisible" is literal: the container only mounts the allowlist, so the rest of
the host simply isn't there.

The container provides a writable private `/tmp` for scratch files. Host `/tmp`
is not mounted; use `--rw DIR` for any explicit shared scratch directory.

Guards: `sandbox` refuses to auto-bind `cwd` when it is `$HOME` or above (which
would re-expose the whole home), and rejects `--rw`/`--ro` of `$HOME` or `/`.
Network is shared by default; `--no-net` cuts it.

## Runtime

A rootless podman container: namespace isolation, sharing the host kernel.

It reuses the host userspace through read-only mounts (`/usr`, toolchains), an
`ubuntu:24.04` base image (`$SANDBOX_IMAGE`), `--userns=keep-id`, and
`--network=host`. They need no root.

## Profiles

A profile is a tiny `*.profile` file sourced by the engine; it appends to the
`RW` / `RO` / `RW_FILES` / `RO_LAST` arrays and can `use NAME` to compose
another. `-p NAME` resolves a bare name against **`$SANDBOX_PROFILE_PATH`**
(default `~/.config/sandbox`); `-p PATH` (containing `/`) loads a file directly.

Profiles live in `~/.config/sandbox` so direct sandbox invocations and `renv`
harnesses use the same profile namespace:

| Profile | Where | Adds |
|---------|-------|------|
| `dev` | `~/.config/sandbox/` | node/bun/fnm toolchains, `~/.gitconfig` (ro) + PATH fixup |
| `machinery-ro` | `~/.config/sandbox/` | RO_LAST pins on the enforcement stack — composed by every `agent-*` profile |
| `agent` | `~/.config/sandbox/` | `use dev` + `machinery-ro` + `~/dotfiles`, `~/.agents` (ro) + `~/org/agents` (rw) |
| `agent-claude` | `~/.config/sandbox/` | `use agent` + that harness's state |
| `agent-pi` | `~/.config/sandbox/` | `use dev` + `machinery-ro` + shared policy (ro) + that harness's own state; deliberately not `agent` — they get only their own control plane, not every `$HOME` config |

## Coding agents (via renv)

The harness env files (`~/.config/renv/{claude,pi}.sh`) own the sandbox
decision — `renv` knows nothing about it. They set
`RENV_WRAP=(sandbox -p agent-<cmd> --)`; `renv` then runs the harness under that
wrapper (a generic feature — an env file may set `RENV_WRAP` to any prefix
command). Comment that line out to disable. Fails closed: if the wrapper errors,
the harness never launches unconfined.

```sh
renv claude         # launches confined (default backend), no extra steps
```

`renv pi` keeps bare `pi` unchanged. It supplies the ASTA MCP key, confines
Git activity to `pi/*`, and invokes pi with
`--sandbox danger-full-access --ask-for-approval never`; the outer sandbox is
therefore the filesystem boundary. Network and MCP access remain enabled.

## One-time setup

- Nothing: rootless podman works out of the box.

## Limits / caveats

- `--network=host`: the agent shares the host network (localhost services, the
  internal network). Convenient for in-the-loop use; not network isolation.
- Environment: only the `SANDBOX_ENV` allowlist crosses the boundary (a small
  base set plus what the profile appends; pinned by `tests/sandbox-env-test.sh`).
  Allowlisted secrets resolved by `renv` (API keys) do ride along by design.
- An agent must see its own login state to authenticate, so its credential
  file is mounted read-only and blocked by the in-process guardrail. That is
  not a secret boundary against the agent process itself.
- No resource caps by default (a too-tight `--memory`/`--pids-limit` would kill an
  interactive agent mid-task; add them only for unattended runs).
- `~/.ssh` / `pass` are absent inside, so `git push` over SSH and `pass` reads
  won't work in the sandbox — do those outside, or pass a token via env.
- The kernel is shared with the host, so this resists mistakes rather than a
  determined kernel exploit. A user-space kernel (gVisor) or a microVM would be
  stronger; the gVisor path was carried here for a year without ever being
  selected or tested, so it was removed rather than left as untested code. The
  microVM route stays closed while the host gates `/dev/kvm`.
