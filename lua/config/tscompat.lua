-- Bridge between telescope and nvim-treesitter's `main` branch.
--
-- telescope's last release predates the nvim-treesitter rewrite and still calls
-- two things that no longer exist:
--
--   nvim-treesitter.parsers.ft_to_lang(ft)          -- parsers is now a plain
--                                                      lang -> install-info table
--   nvim-treesitter.configs.is_enabled(...)         -- the module is gone entirely
--
-- Without them `<leader>f/` throws before its picker opens, and every telescope
-- preview raises "attempt to call field 'ft_to_lang' (a nil value)" instead of
-- highlighting.
--
-- The tempting fix — assigning ft_to_lang onto the parsers table — is a trap:
-- nvim-treesitter builds its language list with vim.tbl_keys(parsers), so a
-- function key shows up as a bogus language in :TSInstall completion and makes
-- config.get_available() index a function. Instead, put the two modules
-- telescope expects into package.loaded only for as long as it takes telescope
-- to look them up, then restore whatever was there before.
--
-- Both replacements are answerable from core Neovim now: vim.treesitter has the
-- filetype -> language map, and "is highlighting enabled for this language" is
-- just "does a parser load".

local M = {}

local function get_parser(bufnr, lang)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr or 0, lang, { error = false })
  if ok then return parser end
  return nil
end

local PARSERS = "nvim-treesitter.parsers"
local CONFIGS = "nvim-treesitter.configs"

local shim_parsers = {
  ft_to_lang = function(ft) return vim.treesitter.language.get_lang(ft) or ft end,
  get_parser = get_parser,
}

local shim_configs = {
  -- Called as configs.is_enabled("highlight", lang, bufnr), so the module name
  -- arrives as the first argument.
  is_enabled = function(_, lang, bufnr) return get_parser(bufnr, lang) ~= nil end,
  get_module = function() return {} end,
}

--- Run `fn` with the two legacy nvim-treesitter modules visible to `require`.
---@param fn fun()
function M.with(fn)
  local saved_parsers, saved_configs = package.loaded[PARSERS], package.loaded[CONFIGS]
  package.loaded[PARSERS], package.loaded[CONFIGS] = shim_parsers, shim_configs
  local ok, err = pcall(fn)
  package.loaded[PARSERS], package.loaded[CONFIGS] = saved_parsers, saved_configs
  if not ok then error(err, 0) end
end

return M
