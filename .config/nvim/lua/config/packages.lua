-- Native package management via vim.pack.

local function plugin_specs()
  return {
    { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", name = "nvim-treesitter" },
    { src = "https://github.com/williamboman/mason.nvim", name = "mason.nvim" },
    { src = "https://github.com/neovim/nvim-lspconfig", name = "nvim-lspconfig" },
    { src = "https://github.com/stevearc/conform.nvim", name = "conform.nvim" },
    { src = "https://github.com/nvim-lua/plenary.nvim", name = "plenary.nvim" },
    { src = "https://github.com/ibhagwan/fzf-lua", name = "fzf-lua" },
    { src = "https://github.com/stevearc/oil.nvim", name = "oil.nvim" },
    { src = "https://github.com/folke/which-key.nvim", name = "which-key.nvim" },
    { src = "https://github.com/lewis6991/gitsigns.nvim", name = "gitsigns.nvim" },
    { src = "https://codeberg.org/andyg/leap.nvim", name = "leap.nvim" },
    { src = "https://github.com/carlos-algms/agentic.nvim", name = "agentic.nvim" },
    { src = "https://github.com/saghen/blink.cmp", name = "blink.cmp", version = vim.version.range("1.*") },
  }
end

local function ensure_final_newline(path)
  local file = io.open(path, "r")
  if not file then
    return
  end

  local content = file:read("*a")
  file:close()

  if content == "" or content:sub(-1) == "\n" then
    return
  end

  file = io.open(path, "a")
  if not file then
    return
  end

  file:write("\n")
  file:close()
end

local function normalize_pack_lock()
  ensure_final_newline(vim.fn.stdpath("config") .. "/nvim-pack-lock.json")
end

local function install_and_load(specs)
  local ok, err = pcall(vim.pack.add, specs, { load = true })

  if not ok then
    vim.schedule(function()
      vim.notify(tostring(err), vim.log.levels.ERROR)
    end)
  end

  normalize_pack_lock()

  return ok
end

return {
  plugin_specs = plugin_specs,
  install_and_load = install_and_load,
}
