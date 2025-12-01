local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4

-- Compile and run maps
map("n", "<leader>c", ":w<CR>:!g++ -std=c++17 -Wall -Wextra % -o %:r 2> /tmp/compile_errors || true<CR>:if filereadable('/tmp/compile_errors') | cfile /tmp/compile_errors | endif<CR>", opts)
map("n", "<leader>x", ":!./%:r<CR>", opts)