-- Single source of truth for LSP servers (lspconfig names).
-- Read by lua/plugins/lsp.lua at runtime and by rpm/build-rpm.sh, which
-- translates these to Mason package names when baking the offline payload.
return {
  "clangd",  -- C/C++ (also supplies C/C++ diagnostics via clang-tidy)
  "pyright", -- Python: types, completion, hover
  "ruff",    -- Python: lint + quick-fix code actions (hover left to pyright)
  "ts_ls",   -- TypeScript/JavaScript
  "html",    -- HTML
  "cssls",   -- CSS
  "jsonls",  -- JSON (schemas from schemastore)
  "lua_ls",  -- Lua (for editing this config)
  "bashls",  -- Bash/Shell (runs shellcheck itself)
}
