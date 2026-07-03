-- ACP (Agent Client Protocol) integration.

local M = {}

local default_provider = "opencode-acp"

local function options()
  return {
    provider = default_provider,
    acp_providers = {
      [default_provider] = {
        command = "opencode",
      },
    },
  }
end

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

function M.setup()
  require("agentic").setup(options())

  map({ "n", "v", "i" }, "<C-\\>", function()
    require("agentic").toggle()
  end, "Toggle Agentic Chat")

  map({ "n", "v" }, "<C-'>", function()
    require("agentic").add_selection_or_file_to_context()
  end, "Add file/selection to context")

  map({ "n", "v", "i" }, "<C-,>", function()
    require("agentic").new_session()
  end, "New Agentic Session")
end

return M
