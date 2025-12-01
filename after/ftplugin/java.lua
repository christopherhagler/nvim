local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4

-- Build command: Compile with javac
local build_cmd = string.format("javac %s", vim.fn.expand("%"))

-- Run command: Run the class file with java
-- Note: We use %:r to get the root name without the .java extension
local run_cmd = string.format("java %s", vim.fn.expand("%:r"))

-- <leader>c to build asynchronously
map('n', '<leader>c', string.format(':OverseerRunCmd %s<CR>', build_cmd), opts)

-- <leader>x to run in a terminal window
map('n', '<leader>x', string.format(':OverseerRunCmd strategy=terminal %s<CR>', run_cmd), opts)