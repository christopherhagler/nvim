require("config.indent").apply()

-- Indentation: see the note in after/ftplugin/c.lua — the global 4-space
-- default is already what clang-format emits here.

require("config.cfamily").setup()
