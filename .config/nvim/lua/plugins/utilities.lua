-- Utilities: fzf-lua, Oil, which-key, gitsigns, and leap.

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

local function setup_leap()
  -- leap.nvim replaces flash.nvim (which FFI-crashes on nvim nightly). No
  -- setup() needed; just the <Plug> mappings. Repo moved GitHub -> Codeberg.
  vim.keymap.set({ "n", "x", "o" }, "s", "<Plug>(leap)", { desc = "Leap" })
  vim.keymap.set({ "n", "x", "o" }, "<leader>j", "<Plug>(leap)", { desc = "Leap" })
  vim.keymap.set("n", "S", "<Plug>(leap-from-window)", { desc = "Leap from window" })
end

function M.setup()
  setup_fzf_lua()
  setup_oil()
  setup_which_key()
  setup_gitsigns()
  setup_leap()
end

return M
