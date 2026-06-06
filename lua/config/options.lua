local opt = vim.opt

vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- Appearance
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.showmode = false

-- Indentation
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.smartindent = true
opt.autoindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Files
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undofile = true
opt.undodir = vim.fn.stdpath("data") .. "/undodir"

-- Behavior
opt.clipboard = "unnamedplus"
opt.mouse = "a"
opt.hidden = true
opt.updatetime = 300
opt.timeoutlen = 500
opt.splitright = true
opt.splitbelow = true
opt.completeopt = "menu,menuone,noselect"

-- Folds via treesitter (all open by default)
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldlevel = 99
