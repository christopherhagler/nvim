local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4

-- Compile and run maps
-- NOTE: These shell commands are brittle. Consider using a task runner plugin later.
map("n", "<leader>c", ":w<CR>:!gcc -Wall -Wextra % -o %:r 2> /tmp/compile_errors || true<CR>:if filereadable('/tmp/compile_errors') | cfile /tmp/compile_errors | endif<CR>", opts)
map("n", "<leader>x", ":!./%:r<CR>", opts)