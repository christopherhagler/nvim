-- User commands. Keymaps live in lua/config/keymaps.lua; this is the half of
-- the interface that takes arguments or is rare enough not to deserve a key.

local command = vim.api.nvim_create_user_command

-- ── Build / run ───────────────────────────────────────────────────────────────
command("Build", function(opts)
  require("config.build").build(opts.args ~= "" and opts.args or nil)
end, { nargs = "*", desc = "Build the project (bare :Build auto-detects)", complete = "shellcmd" })

command("BuildStop", function()
  require("config.build").stop()
end, { desc = "Stop the running build" })

command("Run", function()
  require("config.build").run()
end, { desc = "Run the current file in a terminal split" })

-- ── C/C++ ─────────────────────────────────────────────────────────────────────
command("CompileCommands", function(opts)
  local db = require("config.compiledb")
  if opts.bang then db.fallback() else db.generate() end
end, { bang = true, desc = "Generate compile_commands.json for clangd (! writes a .clangd fallback)" })

-- ── Formatting ────────────────────────────────────────────────────────────────
-- Off by default, matching <leader>lf being the normal way to format here. This
-- is for the projects with a CI formatting gate, where forgetting once costs a
-- round trip.
local fmt_group = vim.api.nvim_create_augroup("format_on_save", { clear = true })

command("FormatOnSave", function()
  vim.g.format_on_save = not vim.g.format_on_save
  vim.api.nvim_clear_autocmds({ group = fmt_group })
  if vim.g.format_on_save then
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = fmt_group,
      callback = function(ev)
        require("conform").format({ bufnr = ev.buf, lsp_format = "fallback", timeout_ms = 2000 })
      end,
    })
  end
  vim.notify("Format on save: " .. (vim.g.format_on_save and "on" or "off"))
end, { desc = "Toggle format-on-save for this session" })
