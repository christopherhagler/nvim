local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4

-- Test command: Run pytest on the current file
local test_cmd = string.format("pytest %s", vim.fn.expand("%"))

-- Run command: Execute the script with python3
local run_cmd = string.format("python3 %s", vim.fn.expand("%"))

-- <leader>c to run tests in a terminal window
map('n', '<leader>c', string.format(':OverseerShell strategy=terminal %s<CR>', test_cmd), opts)

-- <leader>x to run the script in a terminal window
map('n', '<leader>x', string.format(':OverseerShell strategy=terminal %s<CR>', run_cmd), opts)