-- Single source of truth for Mason-managed tools that are *not* LSP servers:
-- formatters, standalone linters, and debug adapters. These are Mason package
-- names (LSP servers live in lua/config/servers.lua).
--
-- Read by lua/plugins/formatting.lua at runtime and by rpm/build-rpm.sh when
-- baking the offline payload for air-gapped systems.
--
-- An entry is either a package name, or `{ name, version = "x.y.z" }` to pin
-- one. Pinning is how a package whose newest prebuilt binary cannot run on
-- RHEL/Rocky 8 stays usable on both halves of the fleet — see stylua below.
return {
  -- Formatters
  "black", "isort", "prettier", "shfmt", "clang-format",
  -- stylua's Linux release is a glibc build, and from v2.3.0 onward it is
  -- linked against GLIBC_2.34 (built on a newer runner). EL8 ships glibc 2.28,
  -- so the current release dies with "version `GLIBC_2.34' not found" the first
  -- time you format a Lua file. v2.0.2 is the newest release that still needs
  -- only 2.28. Mason picks the glibc asset over the musl one whenever both
  -- match the platform, so this cannot be solved by target selection.
  { "stylua", version = "2.0.2" },
  "cmakelang", -- provides cmake-format for CMakeLists.txt
  -- Linters. Anything a language server already covers stays out: shellcheck
  -- is spawned by bashls, C/C++ by clangd's clang-tidy, Python by ruff, and
  -- JS/TS by the eslint server. That leaves the two formats with no server.
  "markdownlint", "yamllint",
  "shellcheck",
  -- Debug adapters
  "codelldb", "cpptools", "debugpy", "js-debug-adapter", "bash-debug-adapter",
}
