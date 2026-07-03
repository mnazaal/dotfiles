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
