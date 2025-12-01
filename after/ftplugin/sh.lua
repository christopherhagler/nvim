local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 2
vim.opt_local.tabstop = 2

-- Lint command: Run shellcheck on the current file
local lint_cmd = string.format("shellcheck %s", vim.fn.expand("%"))

-- Run command: Execute the script with bash
local run_cmd = string.format("bash %s", vim.fn.expand("%"))

-- <leader>c to run linter
map('n', '<leader>c', string.format(':OverseerRunCmd %s<CR>', lint_cmd), opts)

-- <leader>x to run the script in a terminal window
map('n', '<leader>x', string.format(':OverseerRunCmd strategy=terminal %s<CR>', run_cmd), opts)