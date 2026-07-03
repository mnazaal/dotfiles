-- Treesitter: syntax highlighting and folding

local M = {}

local function parsers()
  return {
    "lua",
    "python",
    "bash",
    "markdown",
    "json",
    "yaml",
    "toml",
    "html",
    "css",
    "vim",
    "vimdoc",
    "regex",
  }
end

local function options()
  return {
    install_dir = vim.fn.stdpath("data") .. "/site",
    highlight = {
      enable = true,
    },
    indent = {
      enable = true,
    },
  }
end

function M.setup()
  require("nvim-treesitter").setup(options())
  require("nvim-treesitter").install(parsers())
end

return M
