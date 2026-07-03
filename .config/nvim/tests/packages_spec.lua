local root = vim.fn.getcwd()
local packages_path = root .. "/.config/nvim/lua/config/packages.lua"

local function read_file(path)
  local fd = assert(io.open(path, "r"))
  local content = fd:read("*a")
  fd:close()
  return content
end

local function assert_contains(content, needle, label)
  if not content:find(needle, 1, true) then
    error(label .. " missing: " .. needle)
  end
end

local packages = read_file(packages_path)

assert_contains(packages, "ensure_final_newline", "pack lock newline normalizer")
assert_contains(packages, "nvim-pack-lock.json", "pack lock path")
assert_contains(packages, "content:sub(-1) == \"\\n\"", "newline present check")
assert_contains(packages, "file:write(\"\\n\")", "newline append")

print("packages_spec: ok")
