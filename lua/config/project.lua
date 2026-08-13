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

-- Build-system and packaging files, plus .git as the universal last resort.
-- compile_commands.json is included because a vendored subtree can carry one
-- without a CMakeLists.txt beside it, and that is the directory clangd cares
-- about.
M.MARKERS = {
  "compile_commands.json",
  "CMakeLists.txt",
  "Makefile",
  "makefile",
  "package.json",
  "Cargo.toml",
  "pyproject.toml",
  "setup.py",
  ".git",
}

--- @param source integer|string|nil buffer number or path (default: current buffer)
--- @return string absolute path to the project root, or the cwd
function M.root(source)
  return vim.fs.root(source or 0, M.MARKERS) or vim.uv.cwd()
end

return M
