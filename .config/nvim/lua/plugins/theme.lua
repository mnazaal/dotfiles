local M = {}

local function options()
  return {
    flavour = "mocha",
    transparent_background = true,
    -- fzf and gitsigns are on by default; which_key is not.
    integrations = {
      which_key = true,
    },
  }
end

function M.setup()
  require("catppuccin").setup(options())
  vim.cmd.colorscheme("catppuccin")
end

return M
