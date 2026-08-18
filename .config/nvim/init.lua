vim.g.mapleader = " "
vim.g.maplocalleader = " "

local packages = require("config.packages")

local plugins_ready = packages.install_and_load(packages.plugin_specs())

require("config.options")
require("config.keymaps")
require("config.autocmds")

if plugins_ready then
  require("plugins.theme").setup()
  require("plugins.completion").setup()
  require("plugins.lsp").setup()
  require("plugins.conform").setup()
  require("plugins.treesitter").setup()
  require("plugins.utilities").setup()
  require("plugins.agentic").setup()
end
