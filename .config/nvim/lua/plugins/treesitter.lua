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
  }
end

function M.setup()
  require("nvim-treesitter").setup(options())
  require("nvim-treesitter").install(parsers())

  -- The main-branch rewrite no longer enables highlighting/indent from setup();
  -- start them per-buffer once the parser for the filetype is available.
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("UserTreesitter", {}),
    callback = function(ev)
      local lang = vim.treesitter.language.get_lang(ev.match) or ev.match
      if pcall(vim.treesitter.start, ev.buf, lang) then
        vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end,
  })
end

return M
