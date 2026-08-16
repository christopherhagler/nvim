-- compile_commands.json generation for clangd.
--
-- This is the single thing that decides whether C/C++ in this editor is good or
-- useless. clangd needs to know how each file is actually compiled — the -I
-- paths, the -D defines, the standard. Without that record it falls back to
-- guessing, and the guess is wrong in the most visible way possible: every
-- project header reports as "file not found", so completion, go-to-definition
-- and diagnostics all quietly degrade at once.
--
-- Neither cmake nor make writes that file by default, which is why a working
-- clangd setup usually looks like a one-time incantation someone found once and
-- pasted into a wiki. :CompileCommands is that incantation, picked per project.

local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "compile_commands" })
end

local function restart_clangd()
  -- Which buffers were attached has to be recorded before the clients stop,
  -- because stopping them is what discards that list.
  local attached = {}
  for _, client in ipairs(vim.lsp.get_clients({ name = "clangd" })) do
    for buf in pairs(client.attached_buffers) do
      attached[buf] = true
    end
    client:stop()
  end
  -- Nothing was attached (clangd installed after the file was opened, say), so
  -- reload this buffer instead — that is what starts it for the first time.
  if not next(attached) then attached[vim.api.nvim_get_current_buf()] = true end

  -- Re-reading a buffer re-runs the FileType logic that starts the server, now
  -- that a compile database exists. Half a second is enough for the old process
  -- to exit; :edit while it is still shutting down attaches to nothing.
  vim.defer_fn(function()
    for buf in pairs(attached) do
      -- :edit refuses to discard unsaved changes (E37), and would abort the
      -- loop over the remaining buffers if it errored.
      if vim.api.nvim_buf_is_valid(buf) and not vim.bo[buf].modified then
        vim.api.nvim_buf_call(buf, function() pcall(vim.cmd, "edit") end)
      end
    end
  end, 500)
end

-- cmake writes compile_commands.json into the build directory, but clangd looks
-- for it next to the source (or in ./build). A symlink satisfies both and stays
-- correct as the build directory is regenerated; a copy would go stale.
local function link_to_root(root, build_dir)
  local src = build_dir .. "/compile_commands.json"
  local dst = root .. "/compile_commands.json"
  if not vim.uv.fs_stat(src) then return end

  -- fs_stat follows symlinks, so a link left behind by a deleted build tree
  -- reads as absent while still occupying the name — fs_symlink would then fail
  -- with EEXIST and, since nothing checks its return, clangd would keep running
  -- with no compile database and no explanation. lstat sees the link itself.
  local existing = vim.uv.fs_lstat(dst)
  if existing then
    if existing.type ~= "link" then return end -- a real file: the user's, leave it
    if vim.uv.fs_stat(dst) then return end     -- link already resolves, nothing to do
    vim.uv.fs_unlink(dst)
  end

  local ok, err = vim.uv.fs_symlink(src, dst)
  if not ok then
    notify("Could not link compile_commands.json into the project root: " .. tostring(err), vim.log.levels.WARN)
  end
end

local function run(cmd, root, on_ok)
  notify("Running: " .. table.concat(cmd, " "))
  vim.system(cmd, { cwd = root, text = true }, vim.schedule_wrap(function(res)
    if res.code ~= 0 then
      local err = vim.split((res.stderr or "") .. (res.stdout or ""), "\n", { trimempty = true })
      notify("Failed:\n" .. table.concat(vim.list_slice(err, math.max(1, #err - 5)), "\n"), vim.log.levels.ERROR)
      return
    end
    on_ok()
  end))
end

-- Last resort for projects with no machine-readable build at all (hand-rolled
-- scripts, vendored trees). A .clangd file can't describe per-file flags, but
-- it can stop clangd guessing the language standard and losing the include
-- path, which covers most of the damage.
local function write_clangd_config(root)
  local path = root .. "/.clangd"
  if vim.uv.fs_stat(path) then
    notify(".clangd already exists, leaving it alone", vim.log.levels.WARN)
    return
  end
  local includes = {}
  for _, dir in ipairs({ "include", "inc", "src", "." }) do
    if vim.uv.fs_stat(root .. "/" .. dir) then
      table.insert(includes, "-I" .. dir)
    end
  end

  local compiler = vim.fn.executable("clang") == 1 and "clang" or "gcc"
  local build = require("config.build")

  local lines = {
    "# Written by :CompileCommands as a fallback: this project has no build",
    "# system clangd can read flags from. Prefer a real compile_commands.json.",
    "CompileFlags:",
    "  Add: [-Wall, " .. table.concat(includes, ", ") .. "]",
    "  Compiler: " .. compiler,
  }

  -- The language standard has to be scoped by file extension. clangd applies a
  -- bare CompileFlags.Add to every file it opens, so a project-wide -std=c++20
  -- makes every .c in the tree report "Invalid argument '-std=c++20' not
  -- allowed with 'C'" — an error on line 1 of a file that is perfectly fine.
  --
  -- Headers are left out of both lists on purpose: .h is ambiguous, and letting
  -- clangd infer it from the translation unit including the header is better
  -- than forcing the wrong answer.
  --
  -- Which standard is a question for the compiler, not an assumption: clangd
  -- runs this driver to discover the system include paths, so a flag gcc 8.5 on
  -- EL8 rejects costs the include path, not just the standard.
  local scoped = {
    { lang = "cpp", std = build.supported_std(compiler, "cpp"), match = { [[.*\.cpp]], [[.*\.cc]], [[.*\.cxx]] } },
    { lang = "c",   std = build.supported_std(compiler, "c"),   match = { [[.*\.c]] } },
  }
  for _, entry in ipairs(scoped) do
    if entry.std then
      local patterns = {}
      for _, p in ipairs(entry.match) do
        table.insert(patterns, "'" .. p .. "'")
      end
      vim.list_extend(lines, {
        "---",
        "If:",
        "  PathMatch: [" .. table.concat(patterns, ", ") .. "]",
        "CompileFlags:",
        "  Add: [-std=" .. entry.std .. "]",
      })
    end
  end
  vim.fn.writefile(lines, path)
  notify("Wrote " .. path .. " (fallback flags only)")
  restart_clangd()
end

--- Generate compile_commands.json for the current project and restart clangd.
function M.generate()
  local root = require("config.project").root()

  if vim.uv.fs_stat(root .. "/CMakeLists.txt") then
    if vim.fn.executable("cmake") == 0 then
      notify("CMakeLists.txt found but cmake is not installed", vim.log.levels.ERROR)
      return
    end
    -- Same configure line <leader>bb uses (lua/config/cmake.lua). Two different
    -- invocations would mean two different CMAKE_BUILD_TYPE values landing in
    -- one cache, and each would force a full reconfigure of the other's work.
    local cmake = require("config.cmake")
    local build = cmake.binary_dir(root)
    run(cmake.configure_argv(root), root, function()
      link_to_root(root, build)
      notify("compile_commands.json generated (cmake)")
      restart_clangd()
    end)
    return
  end

  if vim.uv.fs_stat(root .. "/Makefile") or vim.uv.fs_stat(root .. "/makefile") then
    if vim.fn.executable("bear") == 0 then
      notify("make project needs `bear` to record compile flags — install bear, or use :CompileCommands! for a .clangd fallback",
        vim.log.levels.ERROR)
      return
    end
    -- bear observes an actual build, so it only sees the files that actually
    -- get compiled. -B forces every target to rebuild; without it an
    -- already-built tree produces an almost-empty compile_commands.json.
    --
    -- bear 3 separates its own arguments from the build command with `--`;
    -- bear 2, which is what older EPEL 8 repos carry, has no such separator and
    -- fails outright on it. Ask which one is installed rather than guessing.
    local version = vim.system({ "bear", "--version" }, { text = true }):wait()
    local major = tonumber(((version.stdout or "") .. (version.stderr or "")):match("(%d+)%.")) or 3
    local cmd = major >= 3 and { "bear", "--", "make", "-B" } or { "bear", "make", "-B" }

    run(cmd, root, function()
      notify("compile_commands.json generated (bear + make)")
      restart_clangd()
    end)
    return
  end

  notify("No cmake or make project found — writing .clangd fallback", vim.log.levels.WARN)
  write_clangd_config(root)
end

--- Skip detection and write the .clangd fallback (`:CompileCommands!`).
function M.fallback()
  write_clangd_config(require("config.project").root())
end

return M
