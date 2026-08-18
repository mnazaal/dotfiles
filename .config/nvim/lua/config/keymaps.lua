local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

local function expr_map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc, expr = true })
end

map("n", "J", "mzJ`z", "Join lines and keep cursor position")

-- Move by display lines only when wrapping is on, so counts still work.
expr_map("n", "j", "v:count == 0 ? 'gj' : 'j'", "Down by screen line")
expr_map("n", "k", "v:count == 0 ? 'gk' : 'k'", "Up by screen line")

map("n", "n", "nzzzv", "Next search result")
map("n", "N", "Nzzzv", "Prev search result")
map("n", "<C-d>", "<C-d>zz", "Half-page down centered")
map("n", "<C-u>", "<C-u>zz", "Half-page up centered")

-- Preserve paste/delete registers for common editing flows.
map("x", "<leader>p", '"_dP', "Paste without yanking replaced text")
map({ "n", "v" }, "<leader>d", '"_d', "Delete without yanking")

map("n", "<M-j>", "<cmd>m .+1<CR>==", "Move line down")
map("n", "<M-k>", "<cmd>m .-2<CR>==", "Move line up")
map("v", "<M-j>", ":m '>+1<CR>gv=gv", "Move selection down")
map("v", "<M-k>", ":m '<-2<CR>gv=gv", "Move selection up")

map("n", "<leader>yp", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
end, "Copy absolute file path")

map("v", "<", "<gv", "Indent left and reselect")
map("v", ">", ">gv", "Indent right and reselect")

map("t", "<C-w>", "<C-\\><C-n><C-w>", "Window command from terminal")

map("n", "<leader>rc", ":e ~/.config/nvim/init.lua<CR>", "Edit config")
map("n", "<leader>rC", ":Oil ~/.config/nvim<CR>", "Browse config")
