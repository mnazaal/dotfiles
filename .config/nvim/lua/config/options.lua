local function ensure_directory(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
end

local function dotfiles_treesitter_foldexpr()
  local ok, value = pcall(vim.treesitter.foldexpr)
  if ok and value then
    return value
  end

  return "0"
end

local undo_dir = vim.fn.stdpath("state") .. "/undodir"

_G.dotfiles_treesitter_foldexpr = dotfiles_treesitter_foldexpr

-- Basic settings.
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.wrap = false
vim.opt.scrolloff = 10
vim.opt.sidescrolloff = 8

-- Indentation.
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Search settings.
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false

-- Visual settings.
vim.opt.termguicolors = true
vim.opt.guifont = "Iosevka Term:h12"
vim.opt.signcolumn = "yes"
vim.opt.colorcolumn = "100"
vim.opt.showmatch = true
vim.opt.matchtime = 2
vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.pumheight = 10
vim.opt.pumblend = 10
vim.opt.synmaxcol = 300

-- File handling.
vim.opt.writebackup = false
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.updatetime = 300
vim.opt.timeoutlen = 500
vim.opt.ttimeoutlen = 0

-- Undo directory.
ensure_directory(undo_dir)
vim.opt.undodir = undo_dir

-- Behavior settings.
vim.opt.iskeyword:append("-")
vim.opt.path:append("**")
vim.opt.selection = "exclusive"
vim.opt.mouse = "a"
vim.opt.clipboard:append("unnamedplus")

-- Cursor settings.
vim.opt.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,sm:block-blinkwait175-blinkoff150-blinkon175"

-- Folding settings.
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.dotfiles_treesitter_foldexpr()" -- treesitter when available, "0" otherwise
vim.opt.foldlevel = 99

-- Split behavior.
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Command-line completion.
vim.opt.wildmode = "longest:full,full"
vim.opt.wildignore:append({ "*.o", "*.obj", "*.pyc", "*.class", "*.jar" })

-- Better diff options.
vim.opt.diffopt:append("linematch:60")

-- Raised ceilings before nvim gives up on a redraw or a regex; these make it
-- wait longer on heavy files, they do not make it faster.
vim.opt.redrawtime = 10000
vim.opt.maxmempattern = 20000
