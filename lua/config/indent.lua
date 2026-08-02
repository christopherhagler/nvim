-- Per-filetype indentation overrides.
--
-- The global default (4-space, expandtab) lives in lua/config/options.lua;
-- listed here are only the languages whose ecosystem disagrees with it. Each
-- entry is kept in sync with what the configured formatter actually emits, so
-- hand-written and <leader>lf-formatted code match:
--   prettier → 2 spaces (js/ts/web)
--   stylua   → see .stylua.toml (its own default is tabs)
--   shfmt    → 2 spaces via `-i 2` in lua/plugins/formatting.lua (ditto)
--
-- Applied from after/ftplugin/<ft>.lua so these win over the runtime ftplugins.

local M = {}

M.rules = {
  javascript = 2,
  javascriptreact = 2,
  typescript = 2,
  typescriptreact = 2,
  json = 2,
  jsonc = 2,
  yaml = 2,
  html = 2,
  css = 2,
  scss = 2,
  lua = 2,
  markdown = 2,
  sh = 2,
  bash = 2,
  -- Assembly conventionally uses hard tabs, 8 columns wide
  asm = { width = 8, tabs = true },
}

-- Apply the rule for the current buffer's filetype. Called with no arguments
-- from each after/ftplugin file.
function M.apply()
  local rule = M.rules[vim.bo.filetype]
  if not rule then return end
  if type(rule) == "number" then rule = { width = rule } end

  vim.bo.expandtab = not rule.tabs
  vim.bo.shiftwidth = rule.width
  vim.bo.tabstop = rule.width
  vim.bo.softtabstop = rule.width
end

return M
