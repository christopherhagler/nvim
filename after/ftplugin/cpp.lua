local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4

-- Build command: Compile with g++, C++17, and warnings enabled
local build_cmd = string.format("g++ -std=c++17 -Wall -Wextra -o %s.out %s", vim.fn.expand("%:r"), vim.fn.expand("%"))

-- Run command: Execute the compiled binary
local run_cmd = string.format("./%s.out", vim.fn.expand("%:r"))

-- <leader>c to build asynchronously
map('n', '<leader>c', string.format(':OverseerShell %s<CR>', build_cmd), opts)

-- <leader>x to run in a terminal window
map('n', '<leader>x', string.format(':OverseerShell strategy=terminal %s<CR>', run_cmd), opts)