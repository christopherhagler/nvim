-- Single source of truth for Mason-managed tools that are *not* LSP servers:
-- formatters, standalone linters, and debug adapters. These are Mason package
-- names (LSP servers live in lua/config/servers.lua).
--
-- Read by lua/plugins/formatting.lua at runtime and by rpm/build-rpm.sh when
-- baking the offline payload for air-gapped systems.
return {
  -- Formatters
  "black", "isort", "prettier", "stylua", "shfmt", "clang-format",
  -- Linters. shellcheck is spawned by bashls rather than nvim-lint; Python
  -- linting belongs to the ruff LSP server, so only eslint_d runs standalone.
  "eslint_d", "shellcheck",
  -- Debug adapters
  "codelldb", "cpptools", "debugpy", "js-debug-adapter", "bash-debug-adapter",
}
