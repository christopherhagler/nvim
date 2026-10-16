local opt = vim.opt

vim.g.mapleader = ","
-- localleader is kept off ',' so plugin <localleader> defaults (grug-far's,
-- and any added later) cannot land on top of the leader namespace.
vim.g.maplocalleader = "\\"

-- Appearance
opt.winborder      = "rounded"
opt.number         = true
opt.relativenumber = true
opt.cursorline     = true
opt.termguicolors  = true
-- Set explicitly so Neovim skips asking the terminal: in a light-themed
-- terminal that query flips 'background' to light, and tokyonight then loads
-- its light_style ("day") instead of "night".
opt.background     = "dark"
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
-- System clipboard locally. Over SSH there is usually no X/Wayland clipboard
-- tool, so Neovim falls back to OSC 52 — and every `p` then waits on a
-- clipboard *read* that most terminals and tmux never answer. There, yank to
-- the local terminal with OSC 52 but paste from Neovim's own register.
if vim.env.SSH_TTY then
  local osc52 = require("vim.ui.clipboard.osc52")
  local last = { {}, "v" }
  local function copy(reg)
    local send = osc52.copy(reg)
    return function(lines, regtype)
      last = { lines, regtype }
      send(lines, regtype)
    end
  end
  local function paste() return last end
  vim.g.clipboard = {
    name = "OSC 52 (copy only)",
    copy = { ["+"] = copy("+"), ["*"] = copy("*") },
    paste = { ["+"] = paste, ["*"] = paste },
  }
end
opt.clipboard   = "unnamedplus"
opt.mouse       = "a"
opt.updatetime  = 300
opt.timeoutlen  = 500
opt.splitright  = true
opt.splitbelow  = true
opt.completeopt = "menu,menuone,noselect"
-- :q on a modified buffer asks to save instead of failing with E37
opt.confirm     = true

-- Folds (treesitter-based, all open by default)
opt.foldmethod = "expr"
opt.foldexpr   = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel  = 99
