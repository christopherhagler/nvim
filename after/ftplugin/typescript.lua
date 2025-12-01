local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 2
vim.opt_local.tabstop = 2

-- Lint command: Run eslint on the current file
local lint_cmd = string.format("npx eslint %s", vim.fn.expand("%"))

-- Run command: Execute the script with ts-node
local run_cmd = string.format("npx ts-node %s", vim.fn.expand("%"))

-- <leader>c to run linter
map('n', '<leader>c', string.format(':OverseerShell %s<CR>', lint_cmd), opts)

-- <leader>x to run the script in a terminal window
map('n', '<leader>x', string.format(':OverseerShell strategy=terminal %s<CR>', run_cmd), opts)