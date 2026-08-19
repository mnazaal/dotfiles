local M = {}

local function configure_diagnostics()
  vim.diagnostic.config({
    virtual_text = true,
    severity_sort = true,
  })
end

local function lsp_capabilities()
  return require("blink.cmp").get_lsp_capabilities({
    textDocument = {
      completion = {
        completionItem = {
          snippetSupport = false,
        },
      },
    },
  })
end

local function configured_servers()
  return {
    bashls = {},
    cssls = {},
    html = {},
    jsonls = {},
    lua_ls = {
      settings = {
        Lua = {
          runtime = { version = "LuaJIT" },
          diagnostics = { globals = { "vim" } },
          workspace = {
            library = { vim.env.VIMRUNTIME },
            checkThirdParty = false,
          },
          telemetry = { enable = false },
        },
      },
    },
    marksman = {},
    pyright = {
      settings = {
        python = {
          analysis = {
            typeCheckingMode = "basic",
            autoSearchPaths = true,
            useLibraryCodeForTypes = true,
          },
        },
      },
    },
    yamlls = {},
  }
end

local function mason_packages()
  return {
    "css-lsp",
    "html-lsp",
    "json-lsp",
    "lua-language-server",
    "marksman",
    "pyright",
    "yaml-language-server",
    "stylua",
    "shfmt",
    "prettier",
  }
end

local function notify_mason_install_error(package_name, result)
  vim.schedule(function()
    vim.notify(
      string.format("Mason failed to install %s: %s", package_name, tostring(result)),
      vim.log.levels.ERROR
    )
  end)
end

local function notify_mason_install_skip(package_name)
  vim.schedule(function()
    vim.notify(
      string.format(
        "Skipping Mason npm package %s: npm not found. Install it with bun/npm and ensure its executable is on PATH.",
        package_name
      ),
      vim.log.levels.WARN
    )
  end)
end

local function package_uses_npm(pkg)
  local source = pkg.spec and pkg.spec.source
  return type(source) == "table" and type(source.id) == "string" and source.id:sub(1, 8) == "pkg:npm/"
end

local function package_executables(pkg)
  local executables = {}

  if type(pkg.spec) ~= "table" or type(pkg.spec.bin) ~= "table" then
    return executables
  end

  for executable, _ in pairs(pkg.spec.bin) do
    table.insert(executables, executable)
  end

  return executables
end

local function has_any_executable(executables)
  for _, executable in ipairs(executables) do
    if vim.fn.executable(executable) == 1 then
      return true
    end
  end

  return false
end

local function can_install_package(pkg)
  if not package_uses_npm(pkg) or vim.fn.executable("npm") == 1 then
    return true
  end

  if not has_any_executable(package_executables(pkg)) then
    notify_mason_install_skip(pkg.name or "unknown")
  end

  return false
end

local function install_mason_package(registry, package_name, on_success)
  if registry.is_installed(package_name) then
    return
  end

  local ok, pkg = pcall(registry.get_package, package_name)
  if not ok then
    notify_mason_install_error(package_name, pkg)
    return
  end

  if pkg:is_installing() then
    return
  end

  if not can_install_package(pkg) then
    return
  end

  local install_ok, err = pcall(function()
    pkg:install({}, function(success, result)
      if success then
        vim.schedule(on_success)
      else
        notify_mason_install_error(package_name, result)
      end
    end)
  end)

  if not install_ok then
    notify_mason_install_error(package_name, err)
  end
end

local function ensure_mason_packages(package_names, on_success)
  local registry = require("mason-registry")

  registry.refresh(function()
    for _, package_name in ipairs(package_names) do
      install_mason_package(registry, package_name, on_success)
    end
  end)
end

local function executable_exists(cmd)
  if type(cmd) == "string" then
    return vim.fn.executable(cmd) == 1
  end

  if type(cmd) == "table" and #cmd > 0 then
    return vim.fn.executable(cmd[1]) == 1
  end

  return true
end

local function register_servers(servers, capabilities)
  for server, opts in pairs(servers) do
    vim.lsp.config(server, vim.tbl_deep_extend("force", {
      capabilities = capabilities,
    }, opts))
  end
end

local function enable_servers(servers)
  for server, _ in pairs(servers) do
    local server_config = vim.lsp.config[server]
    if server_config and executable_exists(server_config.cmd) then
      vim.lsp.enable(server)
    end
  end
end

local function configure_lsp_attach()
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
      local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc })
      end

      map("gd", vim.lsp.buf.definition, "Go to definition")
      map("gD", vim.lsp.buf.declaration, "Go to declaration")
      map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
      map("<leader>ca", vim.lsp.buf.code_action, "Code actions")
    end,
  })
end

local function configure_diagnostic_keymaps()
  vim.keymap.set("n", "<leader>dl", vim.diagnostic.open_float, { desc = "Diagnostic list" })
  vim.keymap.set("n", "<leader>dq", vim.diagnostic.setloclist, { desc = "Diagnostic quickfix" })
end

function M.setup()
  local servers = configured_servers()
  local capabilities = lsp_capabilities()

  require("mason").setup({})

  configure_diagnostics()
  register_servers(servers, capabilities)
  ensure_mason_packages(mason_packages(), function()
    enable_servers(servers)
  end)
  enable_servers(servers)
  configure_lsp_attach()
  configure_diagnostic_keymaps()
end

return M
