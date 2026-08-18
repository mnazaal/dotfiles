local M = {}

local function options()
  return {
    formatters_by_ft = {
      lua = { "stylua" },
      python = { "ruff_fix", "ruff_format", "ruff_organize_imports" },
      sh = { "shfmt" },
      json = { "prettier", stop_after_first = true },
      ["_"] = { "trim_whitespace" },
    },
    format_on_save = {
      timeout_ms = 500,
      lsp_fallback = true,
    },
  }
end

function M.setup()
  require("conform").setup(options())

  vim.keymap.set({ "n", "v" }, "<leader>f", function()
    require("conform").format({ async = true, lsp_fallback = true })
  end, { desc = "Format buffer" })
end

return M
