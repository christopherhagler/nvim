-- One definition of "the project root", for everything that needs one.
--
-- Five different pieces of this config need to answer the same question — where
-- does the thing I am editing live? — and each of them used to answer it with
-- its own hand-written marker list. That is fine until the lists disagree, at
-- which point the disagreement is invisible: pyright resolves services/api/.venv
-- while the debugger and pytest quietly use the system interpreter, because one
-- of them searched from the file and the others from the shell's cwd.
--
-- vim.fs.root walks up from the buffer and returns the first directory
-- containing any marker, so a flat list means "nearest ancestor that looks like
-- a project" — order does not prioritise (that needs a nested list, see
-- :help vim.fs.root). Falling back to the cwd keeps every caller total: they
-- always get a directory, never nil.

local M = {}

-- Capture startup scope before :cd or another project changes the context.
local startup_dir = vim.uv.cwd()
local startup_root
local settings = {}

--- Register overrides from .nvim.lua. Pass a root when configuring another tree.
--- @param opts table
--- @param root string|nil
function M.setup(opts, root)
  root = vim.fs.normalize(root or startup_root)
  settings[root] = vim.tbl_extend("force", settings[root] or {}, opts)
end

--- Project settings win; legacy globals belong only to the startup project.
--- @param key string
--- @param root string|nil
--- @return any
function M.get(key, root)
  root = root or M.root()
  local value = (settings[vim.fs.normalize(root)] or {})[key]
  if value ~= nil then return value end
  if root == startup_root then return vim.g[key] end
end

-- Build-system and packaging files, plus .git as the universal last resort.
-- compile_commands.json is included because a vendored subtree can carry one
-- without a CMakeLists.txt beside it, and that is the directory clangd cares
-- about.
M.MARKERS = {
  "compile_commands.json",
  "CMakeLists.txt",
  "Makefile",
  "makefile",
  "GNUmakefile",
  "package.json",
  "Cargo.toml",
  "pyproject.toml",
  "setup.py",
  ".git",
}

local function has(dir, names)
  for _, name in ipairs(names) do
    if vim.uv.fs_stat(dir .. "/" .. name) then return true end
  end
  return false
end

local CMAKE = { "CMakeLists.txt" }
local MAKE = { "Makefile", "makefile", "GNUmakefile" }

-- "Nearest marker" is the wrong answer for CMake and for recursive Make: every
-- add_subdirectory() folder has a CMakeLists.txt of its own, and every
-- subdirectory of a kernel, U-Boot or Buildroot tree its own Makefile, so
-- editing drivers/foo.c would make drivers/ the project and <leader>bb would
-- build a fragment as if it were the whole tree. The real project is the
-- topmost such file inside the repository. Outside a repository there is no
-- boundary to stop at, so only an unbroken chain of them is climbed.
local function topmost(dir, names)
  local top = dir
  local stop = vim.fs.root(dir, ".git")
  if stop == dir then return dir end
  for parent in vim.fs.parents(dir) do
    if has(parent, names) then
      top = parent
    elseif not stop then
      break
    end
    if parent == stop then break end
  end
  return top
end

--- @param source integer|string|nil buffer number or path (default: current buffer)
--- @return string absolute path to the project root, or the cwd
function M.root(source)
  local root = vim.fs.root(source or 0, M.MARKERS)
  if not root then return vim.uv.cwd() end
  if has(root, CMAKE) then return topmost(root, CMAKE) end
  if has(root, MAKE) then return topmost(root, MAKE) end
  return root
end

startup_root = M.root(startup_dir)

return M
