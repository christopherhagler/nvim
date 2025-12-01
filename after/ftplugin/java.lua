local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4

-- Compile and run maps
map("n", "<leader>c", ":w<CR>:!javac % 2> /tmp/javac_errors || true<CR>:if filereadable('/tmp/javac_errors') | cfile /tmp/javac_errors | endif<CR>", opts)
map("n", "<leader>x", ":!java %:r<CR>", opts)