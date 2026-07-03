local lib = require("lib")

return {
  ["Makefile"] = { targets = lib.make_prefix() },
  ["meson.build"] = { targets = lib.meson() },
  ["CMakeLists.txt"] = { targets = lib.cmake() },
}
