local opt = vim.opt

vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- Appearance
opt.winborder      = "rounded"
opt.number         = true
opt.relativenumber = true
opt.cursorline     = true
opt.termguicolors  = true
opt.signcolumn     = "yes"
opt.scrolloff      = 8
opt.sidescrolloff  = 8
opt.wrap           = false
opt.showmode       = false
opt.colorcolumn    = "120"
opt.list           = true
opt.listchars      = { tab = "→ ", trail = "·", nbsp = "␣" }

-- Indentation
opt.expandtab   = true
opt.shiftwidth  = 4
opt.tabstop     = 4
opt.softtabstop = 4
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase  = true
opt.hlsearch   = true
opt.incsearch  = true

-- Files
opt.backup       = false
opt.writebackup  = false
opt.swapfile     = false
opt.undofile     = true
opt.undodir      = vim.fn.stdpath("data") .. "/undodir"

-- Project-local config: Neovim sources .nvim.lua / .nvimrc / .exrc from the
-- directory it was started in. 0.11+ asks once per file before running it and
-- remembers the answer (:trust), so an untrusted repo can't execute anything
-- silently. This is what makes the per-project hooks the rest of the config
-- already looks for actually load — vim.g.gdb_path (lua/plugins/dap.lua),
-- vim.g.build_cmd / vim.g.run_cmd (lua/config/build.lua).
opt.exrc = true

-- Behavior
opt.clipboard   = "unnamedplus"
opt.mouse       = "a"
opt.updatetime  = 300
opt.timeoutlen  = 500
opt.splitright  = true
opt.splitbelow  = true
opt.completeopt = "menu,menuone,noselect"

-- Folds (treesitter-based, all open by default)
opt.foldmethod = "expr"
opt.foldexpr   = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel  = 99
