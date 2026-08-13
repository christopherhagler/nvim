-- Single source of truth for treesitter parsers.
-- Read by lua/plugins/editor.lua at runtime and by rpm/build-rpm.sh when
-- baking the offline payload for air-gapped systems.
--
-- Parsers earn their place by driving something: highlighting, indent, folds,
-- or the textobject/move maps in lua/plugins/editor.lua. Several below are
-- injected into other languages rather than used on their own — doxygen
-- inside C/C++ comments, jsdoc inside JS/TS comments.
return {
  "c", "cpp", "python",
  "javascript", "typescript", "tsx",
  "html", "css", "json", "yaml", "toml",
  "lua", "vim", "vimdoc", "bash",
  "markdown", "markdown_inline",
  "asm",
  -- Build systems: CMakeLists.txt and Makefiles are code you edit too
  "cmake", "make",
  -- Comment grammars, injected into the languages above
  "doxygen", "jsdoc",
  -- Git buffers opened by fugitive (commit message, diffs)
  "gitcommit", "diff",
  -- Treesitter's own query language, for editing/inspecting queries
  "query",
}
