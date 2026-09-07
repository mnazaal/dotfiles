# sandbox

Run **any** command confined to an allowlist of directories. One profile front
end over bubblewrap; the coding-agent profiles are just one set of them.

```sh
sandbox -- ./configure && make     # confined to the current repository
sandbox -p dev -- npm test         # + dev toolchains (node/bun/git) read-only
sandbox -n -p dev -- make          # dry-run: print the bwrap command
```

## Model

Only an allowlist is visible. The **repository** containing `$PWD` is
read-write; system dirs and whatever the active profile adds are read-only;
**everything else under `$HOME` — `~/.ssh`, `~/.gnupg`, `~/.password-store`,
other projects — is invisible**. Secrets already in the environment pass
through, so a caller can resolve them *before* entering the sandbox; the vaults
themselves are never mounted.

"Invisible" is literal: only the allowlist is bound, so the rest of the host
simply is not there.

A writable private `/tmp` is provided for scratch files. Host `/tmp` is not
mounted.

**The writable unit is the repository, not `$PWD`.** Two failures come from
getting that wrong, and both are silent. From a subdirectory, binding only
`$PWD` leaves `.git` under a read-only bind, so an agent edits files it can
never commit. From a directory that *contains* repositories, the read-write
bind is emitted after the profile's read-only one and therefore wins — which is
how `cd ~/projects && pi` once handed over every sibling project at once.
So: `$PWD` inside a git worktree binds that worktree (plus its common git dir
for a linked worktree); `$PWD` that is not a worktree and is already bound
read-only by a profile is not auto-bound at all, and the launch says so. Asking
git is what distinguishes a project from a container of projects.

Guards: binding `$HOME` or `/`, or any ancestor of `$HOME`, is refused wherever
it comes from — profiles included, since a hand-written profile is now the only
thing that can ask. The network is shared.

## Runtime

A bubblewrap mount namespace, sharing the host kernel and needing no root. The
root is built by hand from the host: `/usr` and `/etc` read-only, usrmerge
symlinks recreated as symlinks, `/etc/resolv.conf` followed to its real file so
DNS works, and a reconstructed `passwd`/`group` entry when the uid resolves only
through LDAP — without which Node's `os.userInfo()` throws. `$HOME` is shadowed
by a tmpfs before the allowlist is bound back.

Binds apply in argv order and a repeated destination lets the LAST one win.
That is the whole mechanism behind `RO_LAST`, and why no dedupe pass exists.
The emitter sets `SANDBOX_ENGINE=bwrap` inside, since bubblewrap creates
neither `/run/.containerenv` nor `/.dockerenv`; the pi shim reads it to
recognise that it is already sandboxed and step aside rather than nest.

## Profiles

A profile is a tiny `*.profile` file sourced by the launcher; it appends to the
`RW` / `RO` / `RO_LAST` / `MASK` arrays (a mask shadows a path with
an empty tmpfs so it is absent, not merely unwritable) and can `use NAME` to
compose another. `-p NAME` resolves a bare name against
**`$SANDBOX_PROFILE_PATH`** (default `~/.config/sandbox`); `-p PATH`
(containing `/`) loads a file directly.

Profiles are the only way to add a bind. There are no `--rw`/`--ro`/`--mask`
flags: nothing passed them, and the repository rule above covers the case they
existed for.

| Profile | Adds |
|---------|------|
| `dev` | node/bun/fnm toolchains, `~/.gitconfig` (ro) + PATH fixup |
| `machinery-ro` | `RO_LAST` pins on the enforcement stack and `MASK`s on the credential stores — composed by every `agent-*` profile |
| `agent` | `use dev` + `machinery-ro` + `~/dotfiles`, `~/.agents` (ro) + `~/org/agents` (rw) |
| `agent-pi` | `use agent` + pi's control plane read-write, and the environment names pi needs |

## Coding agents

Each harness has a different boundary, and that asymmetry is a decision
(`PLAN.md`, "pi containment"): claude can host its own, pi cannot.

- **`claude` and `claude-agent-acp`** are confined by the `sandbox` block in
  `~/.claude/settings.json` (Claude Code's own bubblewrap, Bash subprocesses
  only, with `permissions.deny` rules covering the file tools). Neither needs a
  launcher: the ACP adapter reads the same settings, verified 2026-09-07 in a
  live Emacs session. The `denyWrite` list there and `machinery-ro.profile` here
  must name the same persistence pins; `tests/sandbox-profile-test.sh` walks the
  PATH for the profile side.
- **`pi`** is `~/.local/scripts/pi`, a shim first on `PATH` that shadows the real
  binary, resolves the ASTA MCP key from `pass` *outside* the boundary (the
  password store is masked inside), and execs the real binary under
  `sandbox -p agent-pi`. Nothing is typed before `pi`. pi's own permission
  extension decides tool calls inside; network and MCP access remain enabled.

`agent-pi` must forward `PI_CODING_AGENT_DIR` and bind `~/.config/pi/agent`
read-write, or pi silently starts with no configuration at all — see that
profile's comments for why.

## One-time setup

On Ubuntu 24.04 an unconfined process that creates a user namespace is moved
into the `unprivileged_userns` AppArmor profile, which breaks bubblewrap
(`loopback: Failed RTM_NEWADDR`). The blanket `/etc/apparmor.d/bwrap` profile
(from `apparmor-profiles`) grants it; the narrow `bwrap-userns-restrict` strips
the capabilities Claude Code's nested step needs and is parked in `disable/`.

## Limits / caveats

- The network is shared (localhost services, the internal network). Convenient
  for in-the-loop use; not network isolation, and egress is accepted rather than
  mitigated (`PLAN.md`, Open risks).
- Environment: only the `SANDBOX_ENV` allowlist crosses (a small base set plus
  what the profile appends; pinned by `tests/sandbox-env-test.sh`). bubblewrap
  inherits the environment and the launcher subtracts with `--unsetenv`, so the
  NAMES of dropped variables are visible in argv via `ps`. Names only, never
  values.
- An agent must see its own login state to authenticate, so its credential file
  is guarded only by the in-process guardrail, never by the boundary. That is
  not a secret boundary against the agent process itself.
- No resource caps by default: a too-tight limit would kill an interactive agent
  mid-task. Add them only for unattended runs.
- `~/.ssh` and `pass` are absent inside, so `git push` over SSH and `pass` reads
  do not work in the sandbox — do those outside, or pass a token via the
  environment.
- The kernel is shared with the host, so this resists mistakes rather than a
  determined kernel exploit. A user-space kernel (gVisor) or a microVM would be
  stronger; the gVisor path was carried for a year without ever being selected
  or tested, so it was removed rather than left as untested code. The microVM
  route stays closed while the host gates `/dev/kvm`.
- **No seccomp filter.** The launcher passes bubblewrap `--unshare-*`,
  `--die-with-parent` and the bind set, and nothing else: the whole syscall
  surface of the shared kernel is reachable. podman applied its default seccomp
  profile, so this is a real reduction that came with the engine change and was
  not weighed at the time. It is consistent with the line above — this boundary
  is about mistakes, not exploits — but it should be a choice rather than an
  omission nobody wrote down.
- **The two harnesses are confined at different scopes, and one is narrower
  than this document's model implies.** Everything above describes whole-process
  confinement, which is what pi gets: the shim execs the agent itself under the
  launcher. The harness-native boundary that claude uses covers its Bash
  subprocesses only; its typed file tools (Read, Edit, Write) are governed by
  `permissions.deny` in settings.json and by the guardrail hook, which are
  in-process policy rather than a kernel boundary. The practical consequence is
  that for claude, a path's protection depends on which tool reaches for it, so
  a rule added in only one of the two layers is not a boundary.
