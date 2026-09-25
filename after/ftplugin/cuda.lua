require("config.indent").apply()

-- CUDA is C++ with extensions, and gets the same buffer setup: include-path
-- gf, <leader>K man pages, <leader>lg. clangd attaches to it as well (cuda is
-- in nvim-lspconfig's clangd filetypes); see lua/config/cuda.lua for the flags
-- it needs to parse .cu files.
require("config.cfamily").setup()

-- The runtime ftplugin sources cpp.vim, which leaves this at /* %s */
vim.bo.commentstring = "// %s"
