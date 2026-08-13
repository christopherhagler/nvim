require("config.indent").apply()

-- Indentation intentionally has no entry in lua/config/indent.lua: the global
-- 4-space default already matches the IndentWidth clang-format is configured
-- with in lua/plugins/formatting.lua.

require("config.cfamily").setup()

-- C99 line comments. The runtime ftplugin still defaults to /* %s */, which
-- makes gcc/gc produce block comments that can't nest around code containing
-- one — the usual reason commenting out a region silently breaks.
vim.bo.commentstring = "// %s"
