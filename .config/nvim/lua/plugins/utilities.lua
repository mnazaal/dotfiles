-- Utilities: fzf-lua, Oil, which-key, gitsigns, and Flash.

local M = {}

local function fzf_lua_options()
  return {
    winopts = {
      height = 0.85,
      width = 0.90,
      preview = { layout = "horizontal" },
    },
  }
end

local function oil_options()
  return {
    default_file_explorer = true,
    columns = { "icon" },
    keep_old_floats = true,
    float_options = {
      border = "rounded",
      winblend = 0,
    },
    keymaps = {
      ["g?"] = "actions.show_help",
      ["<CR>"] = "actions.select",
      ["<C-s>"] = { "actions.select", opts = { vertical = true }, desc = "Open in vertical split" },
      ["<C-h>"] = { "actions.select", opts = { horizontal = true }, desc = "Open in horizontal split" },
      ["<C-t>"] = { "actions.select", opts = { tab = true }, desc = "Open in new tab" },
      ["-"] = "actions.parent",
      ["_"] = "actions.open_cwd",
      ["q"] = "actions.close",
      ["<Esc>"] = "actions.close",
    },
  }
end

local function which_key_options()
  return {
    preset = "modern",
    plugins = {
      spelling = {
        enabled = true,
        suggestions = 20,
      },
    },
    win = {
      border = "single",
      position = "bottom",
      margin = { 1, 0, 1, 0 },
      padding = { 1, 2, 1, 2 },
    },
    layout = {
      width = {
        min = 20,
        max = 50,
      },
      spacing = 3,
    },
    spec = {
      { "<leader>r", group = "+config" },
      { "<leader>f", group = "+find" },
      { "<leader>g", group = "+git" },
      { "<leader>d", group = "+diagnostics" },
    },
  }
end

local function gitsigns_options()
  return {
    signs = {
      add = { text = "│" },
      change = { text = "│" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
      untracked = { text = "┆" },
    },
    signcolumn = true,
    numhl = false,
    linehl = false,
    watch_gitdir = {
      interval = 1000,
      follow_files = true,
    },
    attach_to_untracked = true,
    on_attach = function(buffer)
      local gs = require("gitsigns")

      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = buffer, desc = desc })
      end

      map("n", "]h", gs.next_hunk, "Next hunk")
      map("n", "[h", gs.prev_hunk, "Prev hunk")
      map("n", "<leader>ghs", gs.stage_hunk, "Stage hunk")
      map("n", "<leader>ghr", gs.reset_hunk, "Reset hunk")
      map("v", "<leader>ghs", function()
        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Stage hunk")
      map("n", "<leader>ghS", gs.stage_buffer, "Stage buffer")
      map("n", "<leader>ghu", gs.undo_stage_hunk, "Undo stage hunk")
      map("n", "<leader>ghR", gs.reset_buffer, "Reset buffer")
      map("n", "<leader>ghp", gs.preview_hunk, "Preview hunk")
      map("n", "<leader>ghb", function()
        gs.blame_line({ full = true })
      end, "Blame line")
      map("n", "<leader>ghd", gs.diffthis, "Diff this")
      map("n", "<leader>ghD", function()
        gs.diffthis("~")
      end, "Diff this ~")
      map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Inner hunk")
    end,
  }
end

local function flash_options()
  return {
    search = {
      multi_window = true,
    },
    modes = {
      search = {
        enabled = true,
      },
      char = {
        enabled = false,
      },
    },
    jump = {
      nohlsearch = true,
    },
    label = {
      uppercase = false,
    },
  }
end

local function setup_fzf_lua()
  require("fzf-lua").setup(fzf_lua_options())

  local fzf = require("fzf-lua")
  vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "Find files" })
  vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Grep files" })
  vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Find buffers" })
  vim.keymap.set("n", "<leader>fh", fzf.helptags, { desc = "Help tags" })
end

local function setup_oil()
  require("oil").setup(oil_options())
  vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { desc = "Open parent directory" })
end

local function setup_which_key()
  require("which-key").setup(which_key_options())
end

local function setup_gitsigns()
  require("gitsigns").setup(gitsigns_options())
end

local function setup_flash()
  require("flash").setup(flash_options())

  vim.keymap.set({ "n", "x", "o" }, "s", function()
    require("flash").jump()
  end, { desc = "Flash jump" })

  vim.keymap.set({ "n", "x", "o" }, "<leader>j", function()
    require("flash").jump()
  end, { desc = "Flash jump" })

  vim.keymap.set({ "n", "x", "o" }, "S", function()
    require("flash").treesitter()
  end, { desc = "Flash treesitter" })

  vim.keymap.set("o", "r", function()
    require("flash").remote()
  end, { desc = "Remote flash" })

  vim.keymap.set({ "o", "x" }, "R", function()
    require("flash").treesitter_search()
  end, { desc = "Treesitter search" })

  vim.keymap.set("c", "<C-s>", function()
    require("flash").toggle()
  end, { desc = "Toggle flash search" })
end

function M.setup()
  setup_fzf_lua()
  setup_oil()
  setup_which_key()
  setup_gitsigns()
  setup_flash()
end

return M
