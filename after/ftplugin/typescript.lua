local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- Applies to both .ts and .tsx files automatically due to ftplugin nature
vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 2
vim.opt_local.tabstop = 2

map("n", "<leader>x", ":w<CR>:!ts-node %<CR>", opts)
map("n", "<leader>c", ":w<CR>:!eslint %<CR>", opts)