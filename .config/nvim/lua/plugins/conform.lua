-- Formatting.

local M = {}

local function options()
  return {
    formatters_by_ft = {
      lua = { "stylua" },
      python = { "ruff_fix", "ruff_format", "ruff_organize_imports" },
      bash = { "shfmt" },
      sh = { "shfmt" },
      json = { "prettier", "prettierd" },
      ["_"] = { "trim_whitespace" },
    },
    format_on_save = {
      timeout_ms = 500,
      lsp_fallback = true,
    },
    formatters = {
      stylua = {
        command = "stylua",
        args = { "--search-parent-directories", "-" },
      },
      shfmt = {
        command = "shfmt",
        args = { "-filename", "$FILENAME" },
      },
      ruff_fix = {
        command = "ruff",
        args = { "--fix", "--exit-non-zero-on-fix", "$FILENAME" },
        stdin = false,
      },
      ruff_format = {
        command = "ruff",
        args = { "format", "--filename", "$FILENAME", "-" },
      },
      ruff_organize_imports = {
        command = "ruff",
        args = { "--fix", "--select=I", "$FILENAME" },
        stdin = false,
      },
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
