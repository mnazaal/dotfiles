# Neovim Setup Notes
## Introduction

This config is modular and uses Neovim's native `vim.pack` package manager.
It requires a Neovim version that provides `vim.pack` (currently treated as
Neovim >= 0.12 for this setup).

On startup, the config automatically installs:
- Mason packages: `lua-language-server`, `pyright`, `bash-language-server`, `json-lsp`, `yaml-language-server`, `html-lsp`, `css-lsp`, `marksman`, `stylua`, `shfmt`, `prettier`
- Treesitter parsers: `lua`, `python`, `bash`, `markdown`, `json`, `yaml`, `toml`, `html`, `css`, `vim`, `vimdoc`, `regex`

Plugin versions are rolling. There is no enforced lockfile; update with
`:lua vim.pack.update()` when you want fresh plugin revisions.

Verify health:

```vim
:checkhealth
:LspInfo
:ConformInfo
```

## Command Quick Reference

- `:Mason` opens Mason's UI if you want to inspect or manage installed tools manually.
- `:TSInstall ...` is still available for adding extra Treesitter parsers beyond the default automatic set.

## Config Layout

- `init.lua`: native package install/load + module loading
- `lua/config/packages.lua`: `vim.pack` plugin registry
- `lua/config/options.lua`: editor options
- `lua/config/keymaps.lua`: core keymaps
- `lua/config/autocmds.lua`: autocommands
- `lua/plugins/lsp.lua`: Mason + LSP configuration
- `lua/plugins/treesitter.lua`: Treesitter setup
- `lua/plugins/conform.lua`: formatting setup
- `lua/plugins/utilities.lua`: telescope/oil/which-key/gitsigns/flash
- `ftplugin/*.lua`: filetype-local settings

## Useful Keymaps

- `<leader>rc`: open `init.lua`
- `<leader>rC`: browse the Neovim config directory with Oil
- `<leader>e`: open parent directory with Oil
- `<leader>ff`: find files with Telescope
- `<leader>f`: format buffer with Conform
- `j` / `k`: move by screen lines when no count is provided
- `n` / `N`: next/previous search result centered in the window
- `<C-d>` / `<C-u>`: half-page jump centered in the window
- `<leader>p`: paste over selection without yanking replaced text
- `<leader>d`: delete without yanking
- `<M-j>` / `<M-k>`: move current line or selection
- `<leader>yp`: copy absolute file path
- window movement uses standard Neovim bindings: `<C-w>h/j/k/l`
- `<C-\\>`: toggle Agentic ACP chat
- `<C-'>`: add current file/selection to Agentic context
- `<C-,>`: start a new Agentic session

## ACP / OpenCode

- Neovim includes an ACP client via `carlos-algms/agentic.nvim`.
- It is configured to use `opencode-acp` by default.
- The plugin resolves and launches your `opencode` CLI from `PATH`.
- To use it, make sure `opencode` is installed and working in your shell first.
- Typical check: run `opencode` in a terminal, confirm it can connect/authenticate, then open Neovim and use `<C-\\>`.
- If you ever want to switch providers inside the Agentic window, use the plugin's built-in localleader provider switch.

## Day-to-Day Maintenance

- Update plugins: `:lua vim.pack.update()`
- Update treesitter parsers: `:TSUpdate`
- Manage tools interactively: `:Mason`
- Re-run automatic Mason installs manually if needed: `:MasonToolsInstall`

If something feels off after updates, rerun `:checkhealth` first.

## Runtime Notes

- Startup may fail to install plugins if network or local Git policy blocks `vim.pack`; rerun Neovim or use `:lua vim.pack.update()` after fixing the environment.
- Automatic Mason installation is debounced to run at most weekly on startup; use `:MasonToolsInstall` for immediate/manual installs. Mason and Treesitter installation depends on network access and the underlying package managers succeeding on your machine.
- `ruff` is intentionally not auto-installed via Mason in this config. Mason's `ruff` package creates its own Python virtualenv, and that can fail on systems where `python3 -m venv` / `ensurepip` is unavailable or broken. The config instead uses a system `ruff` binary from `PATH`.
- If you want Mason-managed `ruff` later, first fix Python venv support on your system (for example `python3-venv` or `python3.12-venv` on Debian/Ubuntu), then you can re-add `ruff` to the Mason tool list.
- JSON formatting prefers `prettier`, with `prettierd` as an optional faster fallback if you install it separately.
- Prose-oriented filetypes like Markdown, text, and git commits enable wrapping, line breaks, and spell-checking by default.
- Treesitter-based folding now falls back safely when a parser is missing, but installing the relevant parser still gives the best folding/highlighting experience.
