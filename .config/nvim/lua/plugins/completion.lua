-- Completion: blink.cmp

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
    appearance = {
      nerd_font_variant = "mono",
    },
    completion = {
      menu = {
        auto_show = true,
      },
      documentation = {
        auto_show = false,
      },
    },
    sources = {
      default = { "lsp", "path", "buffer" },
    },
    fuzzy = {
      implementation = "prefer_rust_with_warning",
    },
  }
end

function M.setup()
  require("blink.cmp").setup(options())
end

return M
