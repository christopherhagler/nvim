-- Buffer-local setup shared by after/ftplugin/c.lua and cpp.lua.
--
-- Everything here is the part of C/C++ editing that clangd does *not* cover:
-- clangd answers questions about symbols, but plain Vim mechanics like `gf` on
-- an #include, or reading a libc man page, need the buffer configured for them.

local M = {}

-- Where project headers live, by convention. Absolute paths are appended so
-- 'path' keeps working after :cd, which relative entries do not.
local INCLUDE_DIRS = { "include", "inc", "src", "lib" }

function M.setup()
  local root = require("config.project").root()

  -- gf / <C-w>f / [<C-i> on an #include line. clangd resolves includes for its
  -- own purposes but does not teach Vim's file-finding commands anything, so
  -- without this, jumping to a header only works when the path happens to be
  -- relative to the cwd.
  for _, dir in ipairs(INCLUDE_DIRS) do
    local path = root .. "/" .. dir
    if vim.uv.fs_stat(path) then
      vim.opt_local.path:append(path)
    end
  end
  vim.opt_local.path:append(root)
  vim.opt_local.path:append({ "/usr/local/include", "/usr/include" })

  -- K is LSP hover (bound in lua/plugins/lsp.lua) and answers "what is this
  -- symbol in this project". <leader>K answers the other question — "what does
  -- this libc/POSIX function actually do" — from the system man pages.
  vim.keymap.set("n", "<leader>K", function()
    local word = vim.fn.expand("<cword>")
    if word == "" then return end
    -- Section 3 first (library calls), then 2 (syscalls), then anything.
    for _, section in ipairs({ "3", "2", "" }) do
      local ok = pcall(vim.cmd, ("Man %s %s"):format(section, word))
      if ok then return end
    end
    vim.notify("No man page for " .. word, vim.log.levels.WARN)
  end, { buffer = true, desc = "Man page for word under cursor" })

  -- Generate compile_commands.json for this project. Defined per buffer rather
  -- than globally so the completion and the error message can be specific;
  -- :CompileCommands (lua/config/commands.lua) is the global entry point.
  vim.keymap.set("n", "<leader>lg", function()
    require("config.compiledb").generate()
  end, { buffer = true, desc = "Generate compile_commands.json" })
end

return M
