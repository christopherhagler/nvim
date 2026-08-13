-- Single source of truth for Mason-managed tools that are *not* LSP servers:
-- formatters, standalone linters, and debug adapters. These are Mason package
-- names (LSP servers live in lua/config/servers.lua).
--
-- Read by lua/plugins/formatting.lua at runtime and by rpm/build-rpm.sh when
-- baking the offline payload for air-gapped systems.
return {
  -- Formatters
  "black", "isort", "prettier", "stylua", "shfmt", "clang-format",
  "cmakelang", -- provides cmake-format for CMakeLists.txt
  -- Linters. Anything a language server already covers stays out: shellcheck
  -- is spawned by bashls, C/C++ by clangd's clang-tidy, Python by ruff, and
  -- JS/TS by the eslint server. That leaves the two formats with no server.
  "markdownlint", "yamllint",
  "shellcheck",
  -- Debug adapters
  "codelldb", "cpptools", "debugpy", "js-debug-adapter", "bash-debug-adapter",
}
