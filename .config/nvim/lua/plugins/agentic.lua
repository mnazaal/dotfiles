local M = {}

local default_provider = "pi-acp"

local function options()
  return {
    provider = default_provider,
    acp_providers = {
      [default_provider] = {
        -- ~/.local/scripts/pi-acp, the shim that shadows the real binary on
        -- PATH: it resolves secrets outside the boundary and execs the adapter
        -- under the sandbox profile. Naming the real binary here would run it
        -- unconfined, and the branch prefix pi's guardrails extension sets
        -- would still be absent, so the git hooks would read the session as a
        -- human and let it commit to main.
        command = "pi-acp",
        args = {},
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
