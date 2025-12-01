local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4

-- Define a build task for the current file
local build_cmd = string.format("gcc -Wall -Wextra -o %s.out %s", vim.fn.expand("%:r"), vim.fn.expand("%"))

-- Define a run task for the output binary
local run_cmd = string.format("./%s.out", vim.fn.expand("%:r"))

-- <leader>c to build asynchronously
map('n', '<leader>c', string.format(':OverseerRunCmd %s<CR>', build_cmd), opts)

-- <leader>x to run in a terminal window
map('n', '<leader>x', string.format(':OverseerRunCmd strategy=terminal %s<CR>', run_cmd), opts)
