local root = vim.fn.getcwd()
local lsp_path = root .. "/.config/nvim/lua/plugins/lsp.lua"
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

local function assert_not_contains(content, needle, label)
  if content:find(needle, 1, true) then
    error(label .. " still contains: " .. needle)
  end
end

local lsp = read_file(lsp_path)
local packages = read_file(packages_path)

assert_contains(lsp, "registry.refresh(function()", "Mason v2 refresh install flow")
assert_contains(lsp, "registry.is_installed(package_name)", "Mason v2 installed guard")
assert_contains(lsp, "pkg:is_installing()", "Mason v2 installing guard")
assert_contains(lsp, "pkg:install({}, function(success, result)", "Mason v2 async install callback")
assert_contains(lsp, "package_uses_npm(pkg)", "npm-backed package detection")
assert_contains(lsp, 'vim.fn.executable("npm") == 1', "npm availability guard")
assert_contains(lsp, "has_any_executable", "manual PATH install fallback")
assert_contains(lsp, "Skipping Mason npm package", "npm-missing skip notification")
assert_contains(lsp, "automatic_enable = false", "mason-lspconfig v2 auto-enable guard")
assert_contains(lsp, '"yaml-language-server"', "YAML Mason package name")
assert_contains(lsp, "yamlls =", "YAML LSP server name")
assert_not_contains(lsp, "mason-tool-installer", "LSP setup")
assert_not_contains(packages, "mason-tool-installer.nvim", "Plugin specs")

print("lsp_config_spec: ok")
