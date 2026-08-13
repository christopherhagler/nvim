-- Python interpreter resolution.
--
-- pyright and debugpy both default to whatever `python3` is first on $PATH,
-- which is almost never the interpreter a project's dependencies are installed
-- into. The symptom is subtle rather than loud: imports resolve as missing,
-- types degrade to Unknown, and the debugger launches against the system
-- interpreter — all without an error message.
--
-- This walks up from the project root looking for a virtualenv, the same way a
-- developer would. It is deliberately dependency-free (no fd, no plugin) so it
-- behaves identically on the air-gapped RHEL boxes.
--
-- Consumers: pyright's before_init (lua/plugins/lsp.lua) and dap-python's
-- resolve_python (lua/plugins/dap.lua).

local M = {}

-- Directory names that conventionally hold a project-local virtualenv
local VENV_DIRS = { ".venv", "venv", ".env", "env" }

local cache = {}

local function interpreter(venv)
  local path = venv .. "/bin/python"
  return vim.fn.executable(path) == 1 and path or nil
end

--- Resolve the Python interpreter for a project.
--- @param root string|nil directory to search upward from (default: the current
---   buffer's project root, lua/config/project.lua)
--- @return string|nil absolute path, or nil to let the tool use its own default
function M.python(root)
  -- Defaulting to the cwd rather than the buffer's project root is the bug this
  -- avoids: in a monorepo, pyright passes its own root_dir and finds
  -- services/api/.venv, while the debugger and pytest — which pass nothing —
  -- would resolve against wherever Neovim happened to be started and silently
  -- fall back to the system interpreter.
  root = root or require("config.project").root()

  -- An activated shell venv is an explicit choice by the user; honour it over
  -- anything found on disk.
  if vim.env.VIRTUAL_ENV then
    local active = interpreter(vim.env.VIRTUAL_ENV)
    if active then return active end
  end

  if cache[root] ~= nil then
    -- false is the memoised "searched, found nothing" answer
    return cache[root] or nil
  end

  local found = nil
  for _, name in ipairs(VENV_DIRS) do
    local dir = vim.fs.find(name, { upward = true, path = root, type = "directory" })[1]
    if dir then
      found = interpreter(dir)
      if found then break end
    end
  end

  cache[root] = found or false
  return found
end

--- Forget cached lookups, for after creating a venv without restarting Neovim.
function M.refresh()
  cache = {}
end

return M
