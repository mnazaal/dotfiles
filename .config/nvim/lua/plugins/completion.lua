local M = {}

local function options()
  return {
    keymap = {
      preset = "none",
      ["<C-Space>"] = { "show", "hide" },
      ["<CR>"] = { "accept", "fallback" },
      ["<C-j>"] = { "select_next", "fallback" },
      ["<C-k>"] = { "select_prev", "fallback" },
      ["<Esc>"] = { "hide", "fallback" },
    },
    -- Drops "snippets" from blink's default source list, matching
    -- snippetSupport = false in lsp.lua.
    sources = {
      default = { "lsp", "path", "buffer" },
    },
  }
end

function M.setup()
  require("blink.cmp").setup(options())
end

return M
