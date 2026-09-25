-- MATLAB installation discovery, for matlab_ls (lua/plugins/lsp.lua) and
-- running scripts (lua/config/build.lua).
--
-- The language server is only a thin shell without MATLAB: diagnostics (Code
-- Analyzer), formatting, and most navigation are MATLAB itself answering over
-- a connection the server opens. It needs the install root to open that
-- connection, and it does not look for one on its own.

local M = {}

local cache = nil

local function newest(pattern)
  local found = vim.fn.glob(pattern, false, true)
  -- R2024b sorts after R2024a and R2023b lexically, which is also release order
  table.sort(found)
  return found[#found]
end

--- MATLAB install root (the directory holding bin/matlab), or nil.
--- Override per machine or project with vim.g.matlab_install_path, or $MATLAB_ROOT.
--- @return string|nil
function M.install_path()
  if cache ~= nil then return cache or nil end

  local candidates = { vim.g.matlab_install_path, vim.env.MATLAB_ROOT }
  local exe = vim.fn.exepath("matlab")
  if exe ~= "" then
    -- /usr/local/bin/matlab is normally a symlink into <root>/bin/matlab
    table.insert(candidates, vim.fn.fnamemodify(vim.fn.resolve(exe), ":h:h"))
  end
  if vim.fn.has("mac") == 1 then
    table.insert(candidates, newest("/Applications/MATLAB_R*.app"))
  else
    table.insert(candidates, newest("/usr/local/MATLAB/R*"))
    table.insert(candidates, newest("/opt/MATLAB/R*"))
    table.insert(candidates, newest("/opt/matlab/R*"))
  end

  for _, dir in ipairs(candidates) do
    if dir and dir ~= "" and vim.fn.executable(dir .. "/bin/matlab") == 1 then
      cache = dir
      return dir
    end
  end
  cache = false
  return nil
end

--- The matlab binary, or nil.
function M.bin()
  local root = M.install_path()
  return root and (root .. "/bin/matlab") or nil
end

return M
