-- Single source of truth for LSP servers (lspconfig names).
-- Read by lua/plugins/lsp.lua at runtime and by rpm/build-rpm.sh, which
-- translates these to Mason package names when baking the offline payload.
return {
  "clangd",  -- C/C++ (also supplies C/C++ diagnostics via clang-tidy)
  "pyright", -- Python: types, completion, hover
  "ruff",    -- Python: lint + quick-fix code actions (hover left to pyright)
  "ts_ls",   -- TypeScript/JavaScript
  "eslint",  -- JS/TS lint. Replaces the eslint_d that used to run under
             -- nvim-lint: same engine and same project config, but as a server
             -- it also offers "fix all"/"disable rule" code actions, which
             -- nvim-lint cannot. Only attaches where an eslint config exists.
  "emmet_language_server", -- HTML/CSS/JSX abbreviations (div.foo>ul>li*3<C-y>,)
  "html",    -- HTML
  "cssls",   -- CSS
  "jsonls",  -- JSON (schemas from schemastore)
  "lua_ls",  -- Lua (for editing this config)
  "bashls",  -- Bash/Shell (runs shellcheck itself)
  -- Deliberately not here:
  --
  --   asm_lsp — a Rust binary from GitHub releases, built against a newer glibc
  --   than EL8 ships. It would install on macOS and fail on the RHEL/Rocky half
  --   of the fleet.
  --
  --   cmake (cmake-language-server) — currently broken upstream: it imports
  --   pygls.server.LanguageServer, which pygls 2.x removed, so every install
  --   crash-loops on startup with an ImportError. Verified as of Aug 2026.
  --   CMake files are still covered by treesitter highlighting, cmake-format
  --   (lua/plugins/formatting.lua) and the indent rule in lua/config/indent.lua.
  --   neocmakelsp is the maintained alternative but has the same glibc problem
  --   as asm_lsp.
}
