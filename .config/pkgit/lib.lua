local M = {}

local function status(result, _, code)
  if type(result) == "number" then return result end
  if result == true then return 0 end
  return code or 1
end

function M.sh(cmd)
  return status(os.execute(cmd))
end

function M.q(s)
  s = tostring(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

function M.join(parts, sep)
  sep = sep or " "
  local out = {}
  for _, part in ipairs(parts or {}) do
    if part and part ~= "" then table.insert(out, part) end
  end
  return table.concat(out, sep)
end

-- Like M.join but shell-quotes each token. Use for recipe-supplied build flags
-- so a flag value can't break out of the constructed os.execute string.
function M.qjoin(parts)
  local out = {}
  for _, part in ipairs(parts or {}) do
    if part and part ~= "" then table.insert(out, M.q(part)) end
  end
  return table.concat(out, " ")
end

-- Lua 5.4 randomizes string hashes per process, so pairs() over an options
-- table yields a different order in every run. Nothing downstream cares which
-- order exports or make vars are emitted in, but a build command that is not
-- byte-stable cannot be diffed against a previous run's log — which is the only
-- verification available when the build itself can't be run. Sort.
function M.sorted_pairs(t)
  local keys = {}
  for key in pairs(t or {}) do table.insert(keys, key) end
  table.sort(keys)
  local i = 0
  return function()
    i = i + 1
    if keys[i] ~= nil then return keys[i], t[keys[i]] end
  end
end

function M.git_update_source_only()
  return M.sh([==[
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_dir=$(git rev-parse --git-dir)

  if [ -e "$git_dir/MERGE_HEAD" ] || [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ] || [ -e "$git_dir/CHERRY_PICK_HEAD" ]; then
    printf '%s\n' 'pkgit: refusing to update: git operation already in progress' >&2
    exit 1
  fi

  # An autotools bootstrap rewrites tracked files it does not own: stow's
  # aclocal.m4, rdfind's INSTALL, msmtp's 15 po/ and build-aux files. Refusing
  # here would mean a package's first build permanently blocks its next update,
  # so discard instead — these trees are disposable by policy (see README) and
  # the divergence branch below already resets them. Untracked files, including
  # build/, are left alone.
  if ! git diff --quiet --ignore-submodules=all || ! git diff --cached --quiet --ignore-submodules=all; then
    printf '%s\n' 'pkgit: discarding local changes to tracked files before updating' >&2
    git reset --quiet --hard HEAD || exit 1
  fi

  branch=$(git symbolic-ref --quiet --short HEAD) || {
    printf '%s\n' 'pkgit: detached HEAD (e.g. a pinned version tag); skipping source update' >&2
    exit 0
  }

  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || upstream=origin/$branch
  remote=${upstream%%/*}
  remote_branch=${upstream#*/}

  git fetch --no-tags --prune "$remote" "$remote_branch"

  if ! git diff --quiet --ignore-submodules=all || ! git diff --cached --quiet --ignore-submodules=all; then
    printf '%s\n' 'pkgit: refusing to update: fetch changed local worktree unexpectedly' >&2
    exit 1
  fi

  if git merge-base --is-ancestor HEAD FETCH_HEAD; then
    git merge --ff-only FETCH_HEAD
  elif git merge-base --is-ancestor FETCH_HEAD HEAD; then
    printf 'pkgit: local branch is ahead of %s/%s; leaving it unchanged\n' "$remote" "$remote_branch" >&2
  else
    printf 'pkgit: upstream diverged; resetting clean source checkout to %s/%s\n' "$remote" "$remote_branch" >&2
    git reset --hard FETCH_HEAD
  fi
fi
]==])
end

-- pkgit clones with --recursive, so submodules are right at clone time and then
-- never move again: nothing in the update path touches them. gimp (gimp-data),
-- pwvucontrol, rofi (libgwater, libnkutils) and waybar all carry submodules, so
-- without this an update advances the superproject and builds it against stale
-- submodule content. It also unsticks the dirty-worktree guard above, which a
-- lagging submodule pointer would otherwise trip on every later run.
function M.sync_submodules()
  return M.sh([==[
if [ -f .gitmodules ]; then
  git submodule sync --recursive >/dev/null 2>&1
  git submodule update --init --recursive
fi
]==])
end

-- pkgit's build() ignores a failed chdir into the package source dir, so a
-- recipe invoked for a package that was never cloned would run in whatever
-- directory pkgit was called from. Refuse instead of building somewhere random.
function M.require_source_tree()
  return M.sh([==[
case "$PWD" in
  */share/pkgit/*) exit 0 ;;
  *) printf '%s\n' 'pkgit: refusing: not in a pkgit source tree' >&2; exit 1 ;;
esac
]==])
end

function M.target(t)
  if t.build then
    local build = t.build
    t.build = function()
      local code = M.git_update_source_only()
      if code ~= 0 then return code end
      code = M.sync_submodules()
      if code ~= 0 then return code end
      return build()
    end
  end
  -- pkgit validates `dependencies` on the resolved target profile
  -- (targets.<profile>.dependencies) before building; default to empty since no
  -- inter-package deps are declared. default and quiet share the same table `t`.
  t.dependencies = t.dependencies or {}
  -- Update profile, run as `pkgit -b <pkg>,update`. It is the only way to
  -- re-run a recipe against an existing checkout: `pkgit -i` returns early once
  -- the source dir exists, and `pkgit -u`/`-f` delete that dir while pkgit's own
  -- cwd is inside it, which wrecks the tree. t.build already carries
  -- git_update_source_only, so this is fetch + ff-merge + build + install in
  -- place. pkgit calls the resolved profile's `build` and requires a 0 return.
  local u = { dependencies = {} }
  u.build = function()
    local guard = M.require_source_tree()
    if guard ~= 0 then return guard end
    local code = t.build and t.build() or 0
    if code ~= 0 then return code end
    return t.install and t.install() or 0
  end
  return { default = t, quiet = t, update = u }
end

function M.clean_root_ninja_build()
  return M.sh("if [ -f build/.ninja_deps ] && [ \"$(stat -c %U build/.ninja_deps)\" = root ]; then rm -rf build; fi")
end

function M.clean_unwritable_meson_log()
  return M.sh("if [ -f build/meson-logs/install-log.txt ] && [ ! -w build/meson-logs/install-log.txt ]; then rm -rf build; fi")
end

function M.make_prefix(opts)
  opts = opts or {}
  -- Extra `VAR=value` make args, for Makefiles that hardcode a system dir
  -- (e.g. pass-otp's BASHCOMPDIR=/etc/bash_completion.d) which must be pointed
  -- at a user-writable path for a ~/.local install.
  local extra = ""
  for name, value in M.sorted_pairs(opts.vars) do
    extra = extra .. " " .. name .. "=" .. M.q(value)
  end
  local t = {}
  t.build = function() return M.sh("make PREFIX=" .. M.q(prefix) .. extra) end
  t.install = function() return M.sh("make PREFIX=" .. M.q(prefix) .. extra .. " install") end
  t.uninstall = function() return M.sh("make PREFIX=" .. M.q(prefix) .. extra .. " uninstall") end
  return M.target(t)
end

function M.meson(opts)
  opts = opts or {}
  -- Export the local pkgconfig for the whole command — meson setup, ninja, and
  -- any cargo/custom subproject it spawns (they run their own pkg-config that
  -- reads PKG_CONFIG_PATH from the env). pkgit runs build and install as
  -- SEPARATE shells, so the export must be applied to each; a single script
  -- would get this for free. Append to any existing value rather than replace.
  local function with_pcp(cmd)
    local exports = ""
    if opts.pkg_config_path then
      exports = exports .. "export PKG_CONFIG_PATH=" .. M.q(opts.pkg_config_path) ..
        '${PKG_CONFIG_PATH:+:"$PKG_CONFIG_PATH"}; '
    end
    -- General prepend-to-existing env exports (e.g. GI_TYPELIB_PATH / LD_LIBRARY_PATH /
    -- XDG_DATA_DIRS at prefix), for builds that run an in-tree tool which dlopens or
    -- introspects prefix libs — works even when the session env (e.g. mango's) lacks them.
    for name, value in M.sorted_pairs(opts.env) do
      exports = exports .. "export " .. name .. "=" .. M.q(value) ..
        '${' .. name .. ':+:"$' .. name .. '"}; '
    end
    return exports .. cmd
  end
  local t = {}
  t.build = function()
    -- pkgit's own per-package `version` field is a no-op in the installed
    -- binary (it always clones ref HEAD), so pin a release tag/branch here
    -- instead. `--detach` leaves HEAD detached, which git_update_source_only
    -- then skips on later builds. Idempotent: re-checking-out the same tag is
    -- a no-op. Runs after git_update_source_only has ff-merged the default
    -- branch on the very first (fresh-clone) build.
    if opts.checkout then
      local code = M.sh("git checkout --detach " .. M.q(opts.checkout))
      if code ~= 0 then return code end
      -- The pin moves HEAD after M.target already synced submodules, so sync
      -- again to land them on what the pinned commit records.
      code = M.sync_submodules()
      if code ~= 0 then return code end
    end
    if opts.clean_root_build then M.clean_root_ninja_build() end
    if opts.clean_unwritable_log then M.clean_unwritable_meson_log() end
    local flags = M.qjoin(opts.flags or {})
    local cmd = "meson setup build --prefix=" .. M.q(prefix) .. " --reconfigure"
    if flags ~= "" then cmd = cmd .. " " .. flags end
    return M.sh(with_pcp(cmd .. " && ninja -C build"))
  end
  -- `--only-changed` preserves byte-identical files instead of rewriting the
  -- whole install set, which `ninja install` does unconditionally. Matters now
  -- that the update profile re-installs on every run.
  t.install = function() return M.sh(with_pcp("meson install -C build --only-changed")) end
  t.uninstall = function() return M.sh("ninja -C build uninstall") end
  return M.target(t)
end

function M.cmake(opts)
  opts = opts or {}
  local t = {}
  t.build = function()
    local flags = {
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_PREFIX=" .. M.q(prefix),
    }
    if opts.ccache then
      table.insert(flags, "-DCMAKE_C_COMPILER_LAUNCHER=ccache")
      table.insert(flags, "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache")
    end
    for _, flag in ipairs(opts.flags or {}) do table.insert(flags, M.q(flag)) end
    return M.sh("cmake -S . -B build " .. M.join(flags) .. " && cmake --build build")
  end
  t.install = function() return M.sh("cmake --install build") end
  t.uninstall = function() return M.sh("[ -f build/install_manifest.txt ] && xargs -d '\\n' -r rm -f < build/install_manifest.txt || true") end
  return M.target(t)
end

function M.autotools(opts)
  opts = opts or {}
  -- Extra `VAR=value` make args, applied to build + install + uninstall, for
  -- Makefiles that hardcode an absolute system dir (e.g. nautilus-dropbox's
  -- NAUTILUS_EXTENSION_DIR=/usr/lib/.../nautilus/extensions-4, which needs
  -- pointing under prefix so a ~/.local install doesn't hit EACCES on /usr).
  local mkvars = ""
  for name, value in M.sorted_pairs(opts.make_vars) do
    mkvars = mkvars .. " " .. name .. "=" .. M.q(value)
  end
  local t = {}
  t.build = function()
    local steps = {}
    if opts.autogen then table.insert(steps, "./autogen.sh") end
    -- Generate ./configure from configure.ac when the repo doesn't ship it
    -- (rdfind etc.). Equivalent to a project's bootstrap.sh/autogen.sh but
    -- name-agnostic. A fresh clone needs it; a checkout bootstrapped once by
    -- hand hides the need.
    if opts.autoreconf then table.insert(steps, "autoreconf -fi") end
    local flags = M.qjoin(opts.configure_flags or {})
    local cfg = "./configure --prefix=" .. M.q(prefix)
    if flags ~= "" then cfg = cfg .. " " .. flags end
    table.insert(steps, cfg)
    table.insert(steps, (opts.parallel and 'make -j"$(nproc)"' or "make") .. mkvars)
    return M.sh(M.join(steps, " && "))
  end
  t.install = function() return M.sh("make install" .. mkvars) end
  t.uninstall = function() return M.sh("make uninstall" .. mkvars) end
  return M.target(t)
end

function M.install_bin(src, name)
  return M.sh("install -Dm755 " .. M.q(src) .. " " .. M.q(prefix .. "/bin/" .. name))
end

return M
