local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- Set indentation
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4

-- Keybindings for running code
map("n", "<leader>x", ":w<CR>:!python3 %<CR>", opts)
map("n", "<leader>c", ":w<CR>:!pytest %<CR>", opts)