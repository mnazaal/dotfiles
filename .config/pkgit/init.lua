local home = os.getenv("HOME")

prefix = os.getenv("PREFIX") or (home .. "/.local")

install_directories = {
  bin = prefix .. "/bin",
  include = prefix .. "/include",
  lib = prefix .. "/lib",
  src = prefix .. "/share/pkgit",
}

build_systems = require("build-systems")
repositories = require("packages.all")

-- pkgit's build path validates a `dependencies` table. The fields it actually
-- checks are the per-package entry (packages/all.lua) and the resolved target
-- profile (lib.lua M.target) — this top-level global is belt-and-suspenders.
-- Empty: no inter-package deps are declared (packages are built in order).
dependencies = {}
