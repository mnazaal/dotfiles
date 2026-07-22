local M = {}

local function options()
  return {
    flavour = "mocha",
    transparent_background = true,
    integrations = {
      fzf = true,
      gitsigns = true,
      treesitter = true,
      which_key = true,
    },
  }
end

function M.setup()
  require("catppuccin").setup(options())
  vim.cmd.colorscheme("catppuccin")
end

return M
