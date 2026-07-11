-- Single source of truth for treesitter parsers.
-- Read by lua/plugins/editor.lua at runtime and by rpm/build-rpm.sh when
-- baking the offline payload for air-gapped systems.
return {
  "c", "cpp", "python",
  "javascript", "typescript", "tsx",
  "html", "css", "json", "yaml",
  "lua", "vim", "vimdoc", "bash",
  "markdown", "markdown_inline",
  "asm",
}
