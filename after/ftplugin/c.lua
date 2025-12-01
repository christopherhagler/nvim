local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

vim.opt_local.expandtab = true
vim.opt_local.shiftwidth = 4
vim.opt_local.tabstop = 4

-- ============================================================================
-- Define build, run, and clean commands
-- ============================================================================

-- 1. Build Command: Run 'make'
--    This uses your project's Makefile to build the 'all' target.
--    This is much smarter than a simple 'gcc' command because it handles
--    dependencies, include paths, and linking automatically.
local build_cmd = "make"

-- 2. Run Command: Execute the target defined in your Makefile
--    Your Makefile defines the target as 'build/test_runner'.
local run_cmd = "./build/test_runner"

-- 3. Clean Command: Run 'make clean'
local clean_cmd = "make clean"


-- ============================================================================
-- Create key mappings to run these commands as asynchronous Overseer tasks
-- ============================================================================

-- <leader>c to run 'make' (Build the project)
map('n', '<leader>c', string.format(':OverseerShell %s<CR>', build_cmd), opts)

-- <leader>x to run the final executable in a terminal window
map('n', '<leader>x', string.format(':OverseerShell %s --strategy=terminal<CR>', run_cmd), opts)

-- <leader>cl to run 'make clean'
map('n', '<leader>cl', string.format(':OverseerShell %s<CR>', clean_cmd), opts)
