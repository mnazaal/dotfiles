-- Neovim config.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local packages = require("config.packages")

local plugins_ready = packages.install_and_load(packages.plugin_specs())

-- Load core config modules.
require("config.options")
require("config.ui")
require("config.keymaps")
require("config.autocmds")

-- Load plugin setup modules.
if plugins_ready then
  require("plugins.theme").setup()
  require("plugins.completion").setup()
  require("plugins.lsp").setup()
  require("plugins.conform").setup()
  require("plugins.treesitter").setup()
  require("plugins.utilities").setup()
  require("plugins.agentic").setup()
end
