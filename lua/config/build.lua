-- Build and run, for every language this config supports.
--
-- Nothing here needs a plugin. `:make` would give us the quickfix half of this
-- for free, but it blocks the UI for the length of the compile, which on a real
-- C++ tree means Neovim is frozen for a minute. So builds run through
-- vim.system() and the output is parsed into the quickfix list with the same
-- 'errorformat' machinery :make would have used — async, but ]q / [q still walk
-- the errors (lua/config/keymaps.lua).
--
-- Two responsibilities, deliberately kept apart:
--   build() — whole project, output to quickfix, non-interactive
--   run()   — current file, output to a terminal split, can read stdin
--
-- Both accept a project-local override from a .nvim.lua (see 'exrc' in
-- lua/config/options.lua), which is how a project with an unusual toolchain
-- opts out of the detection below:
--   require("config.project").setup({
--     build_cmd = "ninja -C out/debug",
--     run_cmd = "./out/debug/server --config dev.toml",
--   })

local M = {}

-- Parsers for build output. Vim's default 'errorformat' already understands
-- gcc/clang (file:line:col: error: msg), so C, C++ and anything driven by
-- make/cmake fall through to it; only the languages whose runtimes report
-- errors in their own shape need an entry.
local ERRORFORMAT = {
  -- Python tracebacks: the location line comes before the message line, so the
  -- multiline %A/%C/%Z form is required (this is $VIMRUNTIME/compiler/pyunit).
  python = [[%C %.%#,%A  File "%f"\, line %l%.%#,%Z%[%^ ]%\@=%m]],
  lua = "%f:%l: %m",
  sh = "%f: line %l: %m",
  bash = "%f: line %l: %m",
  -- node stack frames: "    at fn (/abs/path/file.js:12:5)"
  javascript = "%.%#at %.%# (%f:%l:%c),%f:%l:%c: %m,%f:%l:%m",
}
ERRORFORMAT.typescript = ERRORFORMAT.javascript
ERRORFORMAT.javascriptreact = ERRORFORMAT.javascript
ERRORFORMAT.typescriptreact = ERRORFORMAT.javascript

-- nvcc's own front end reports `kernel.cu(42): error: ...` — parentheses where
-- gcc uses a colon, and no column — which the default 'errorformat' does not
-- match, so a failed CUDA build opened an empty quickfix list. Prepended to the
-- default for every compiled language rather than keyed on the current buffer's
-- filetype: a CMake project with CUDA targets is as likely to be built from a
-- .cpp or CMakeLists.txt buffer as from a .cu one. Warnings carry a number
-- (`warning #177-D: ...`), which %*[^:] skips.
local NVCC_EFM = table.concat({
  "%f(%l): %trror: %m",
  "%f(%l): %tarning%*[^:]: %m",
  "%f(%l): catastrophic %trror: %m",
}, ",")

-- Kept as an alias so callers inside this file read naturally; the definition
-- lives in lua/config/project.lua, shared with clangd, dap, neotest and venv.
function M.root()
  return require("config.project").root()
end

local function exists(root, name)
  return vim.uv.fs_stat(root .. "/" .. name) ~= nil
end

-- Where single-file builds put their binary. Never next to the source: an
-- untracked a.out in the working tree is noise in every git status afterwards.
local function scratch_bin()
  local dir = vim.fn.stdpath("cache") .. "/build"
  vim.fn.mkdir(dir, "p")
  return dir .. "/" .. vim.fn.expand("%:t:r")
end

-- Language standards, newest first. Which of these the compiler actually
-- accepts is not something to assume: RHEL/Rocky 8 ship gcc 8.5, which predates
-- -std=c++20 entirely (it has a partial -std=c++2a), while clang on macOS takes
-- anything here. Hardcoding c++20 produces a flag error on half the fleet, so
-- ask the compiler once and remember the answer.
local STANDARDS = {
  c   = { "c17", "c11", "c99" },
  cpp = { "c++20", "c++17", "c++14" },
}

local std_cache = {}

--- Newest language standard `compiler` accepts, or nil if none of them work.
--- Exported because the .clangd fallback (lua/config/compiledb.lua) has to
--- write a standard the system compiler actually understands, for the same
--- reason.
--- @param compiler string binary to probe
--- @param lang "c"|"cpp"
--- @return string|nil
function M.supported_std(compiler, lang)
  local key = compiler .. ":" .. lang
  if std_cache[key] ~= nil then
    return std_cache[key] or nil
  end
  for _, std in ipairs(STANDARDS[lang]) do
    -- -fsyntax-only on an empty file: no output, no linking, ~10ms, and both
    -- gcc and clang reject an unknown -std with a non-zero exit.
    local probe = vim.system(
      { compiler, "-std=" .. std, "-fsyntax-only", "-x", lang == "cpp" and "c++" or "c", "/dev/null" },
      { text = true }
    ):wait()
    if probe.code == 0 then
      std_cache[key] = std
      return std
    end
  end
  std_cache[key] = false -- probed, nothing worked: fall back to the default
  return nil
end

-- Compile the current file on its own, for the scratch-file case: a scratch
-- .c with a main() and no build system around it.
local function single_file_build()
  local src = vim.fn.expand("%:p")
  if src == "" then return nil end
  local ft = vim.bo.filetype

  if ft == "cuda" then
    local nvcc = require("config.cuda").bin("nvcc")
    if not nvcc then
      vim.notify("No nvcc found (set $CUDA_HOME, or add the toolkit's bin/ to $PATH)", vim.log.levels.ERROR)
      return nil
    end
    -- -G: device-side debug info, so cuda-gdb can step inside kernels. It also
    -- disables device optimisation, which is the right trade for a scratch file.
    return ("%s -g -G -Xcompiler -Wall -o %s %s"):format(
      vim.fn.shellescape(nvcc), vim.fn.shellescape(scratch_bin()), vim.fn.shellescape(src))
  end

  if ft ~= "c" and ft ~= "cpp" then return nil end

  local compiler = ft == "c" and (vim.env.CC or "cc") or (vim.env.CXX or "c++")
  -- $CC may carry a launcher or flags ("ccache gcc", "clang -m32"): only the
  -- first word is a program. The whole string is still what runs, unquoted, so
  -- the shell splits it the same way make would.
  local program = vim.split(vim.trim(compiler), "%s+")[1]
  if vim.fn.executable(program) == 0 then
    vim.notify(("No %s compiler found (%s)"):format(ft == "c" and "C" or "C++", compiler), vim.log.levels.ERROR)
    return nil
  end

  local std = M.supported_std(program, ft)
  return ("%s%s -Wall -Wextra -g -o %s %s"):format(
    compiler,
    std and (" -std=" .. std) or "",
    vim.fn.shellescape(scratch_bin()),
    vim.fn.shellescape(src)
  )
end

--- The command `build()` would run, and why. Detection order matters: a C++
--- project with both CMakeLists.txt and a wrapper Makefile wants cmake.
--- @return string|nil cmd, string label
function M.build_cmd()
  local override = require("config.project").get("build_cmd")
  if override then return override, "project build_cmd" end

  local root = M.root()
  if exists(root, "CMakeLists.txt") then
    -- Configure every time: it is a no-op once the cache exists, and it means
    -- a fresh clone builds on the first <leader>bb rather than erroring. The
    -- build type, target and preset come from lua/config/cmake.lua, which also
    -- keeps the export flag on so compile_commands.json stays in step with
    -- clangd — and which passes CMAKE_BUILD_TYPE, without which the build
    -- carries no -g and every breakpoint silently fails to bind.
    return require("config.cmake").build_cmd(root)
  elseif exists(root, "Makefile") or exists(root, "makefile") then
    return "make", "make"
  elseif exists(root, "Cargo.toml") then
    return "cargo build", "cargo"
  elseif exists(root, "package.json") and M.has_build() then
    return "npm run build", "npm"
  end

  local single = single_file_build()
  if single then return single, "single file" end
  return nil, "none"
end

-- A failed write must never launch code from an older version on disk.
local function save(command)
  local ok, err = pcall(vim.cmd, "silent " .. command)
  if not ok then
    vim.notify("Save failed; command cancelled: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  local buffers = command == "wall" and vim.api.nvim_list_bufs() or { vim.api.nvim_get_current_buf() }
  for _, buf in ipairs(buffers) do
    local bo = vim.bo[buf]
    if bo.modified and bo.buftype == "" and (command ~= "wall" or bo.buflisted) then
      vim.notify("Save failed; command cancelled: buffer still has unsaved changes", vim.log.levels.ERROR)
      return false
    end
  end
  return true
end

local job = nil

--- Whether build() would find something to build for the current buffer, used
--- by <leader>bd: an interpreted file has no build step, and debugging it
--- should not wait on one.
function M.has_build()
  if require("config.project").get("build_cmd") then return true end
  local root = M.root()
  for _, name in ipairs({ "CMakeLists.txt", "Makefile", "makefile", "Cargo.toml" }) do
    if exists(root, name) then return true end
  end
  if exists(root, "package.json") then
    -- npm run build with no "build" script is an error, not a no-op
    local ok, pkg = pcall(vim.json.decode, table.concat(vim.fn.readfile(root .. "/package.json"), "\n"))
    return ok and type(pkg) == "table" and type(pkg.scripts) == "table" and pkg.scripts.build ~= nil
  end
  local ft = vim.bo.filetype
  return ft == "c" or ft == "cpp" or ft == "cuda"
end

--- Build the project asynchronously into the quickfix list.
--- @param cmd string|nil overrides detection
--- @param on_success function|nil run after a zero-exit build, on the main loop.
---   This is what makes "build, then debug" one keypress (<leader>bd) rather
---   than a build you have to watch before pressing <F5> yourself.
function M.build(cmd, on_success)
  if job then
    vim.notify("A build is already running (<leader>bk to stop it)", vim.log.levels.WARN)
    return
  end

  local label = "custom"
  if not cmd then cmd, label = M.build_cmd() end
  if not cmd then
    vim.notify("No build system found, and " .. vim.bo.filetype .. " has no single-file build", vim.log.levels.WARN)
    return
  end

  local root = M.root()
  -- A language's own errorformat applies only when the build *is* that
  -- language's file. A project build (cmake, make, a custom command) prints
  -- compiler output whichever buffer it was started from — reading gcc errors
  -- with the shell format from a .sh buffer gave an empty quickfix list.
  local efm = (label == "single file" and ERRORFORMAT[vim.bo.filetype])
    or (NVCC_EFM .. "," .. vim.o.errorformat)
  if not save("wall") then return end
  vim.notify(("Building (%s): %s"):format(label, cmd), vim.log.levels.INFO)

  -- detach: the build gets its own process group, so <leader>bk can signal
  -- cmake/make/the compilers as well as the sh wrapper (see stop()).
  job = vim.system({ "sh", "-c", "exec 2>&1\n" .. cmd }, { cwd = root, text = true, detach = true }, vim.schedule_wrap(function(res)
    job = nil
    -- Merge streams in the shell so directory messages and diagnostics stay
    -- in order; make's directory stack depends on their original sequence.
    local output = (res.stderr or "") .. (res.stdout or "")
    -- Seed errorformat's directory stack with the captured build root.
    -- This also preserves make's nested Entering/Leaving directory handling.
    local lines = vim.split(output, "\n", { trimempty = true })
    table.insert(lines, 1, "NVIM_BUILD_ROOT:" .. root)
    local parsed = vim.fn.getqflist({ lines = lines, efm = "%DNVIM_BUILD_ROOT:%f," .. efm }).items
    table.remove(parsed, 1) -- synthetic directory line
    vim.fn.setqflist({}, " ", { title = cmd, items = parsed })

    local items = vim.fn.getqflist()
    local valid = #vim.tbl_filter(function(i) return i.valid == 1 end, items)

    if res.code == 0 then
      vim.cmd("cclose")
      vim.notify(valid > 0 and ("Build OK, " .. valid .. " warning(s)") or "Build OK", vim.log.levels.INFO)
      if on_success then on_success() end
    else
      if valid > 0 then
        vim.cmd("botright copen")
        vim.cmd("wincmd p") -- copen steals focus; the cursor belongs in the code
      end
      vim.notify(("Build failed (exit %d), %d diagnostic(s)"):format(res.code, valid), vim.log.levels.ERROR)
    end
  end))
end

function M.stop()
  if not job then
    vim.notify("No build running", vim.log.levels.INFO)
    return
  end
  -- SIGTERM to the whole process group. Signalling only the sh wrapper left
  -- cmake, make and the compilers running; they kept the output pipe open, so
  -- the exit callback never fired and every later build reported "already
  -- running".
  if not vim.uv.kill(-job.pid, "sigterm") then job:kill("sigterm") end
  vim.notify("Build stopped", vim.log.levels.WARN)
end

-- Interpreter/command for running the current file. C and C++ compile first and
-- run the result, chained with && so a failed compile never runs a stale binary.
local function run_cmd()
  local override = require("config.project").get("run_cmd")
  if override then return override end

  local file = vim.fn.shellescape(vim.fn.expand("%:p"))
  local ft = vim.bo.filetype

  if ft == "c" or ft == "cpp" or ft == "cuda" then
    local compile = single_file_build()
    return compile and (compile .. " && " .. vim.fn.shellescape(scratch_bin()))
  elseif ft == "matlab" or ft == "octave" then
    -- run() rather than calling the script by name: it cds into the file's
    -- folder for the duration, so the script's own functions and data files
    -- resolve the way they do in the MATLAB editor. Single quotes are doubled
    -- because the path sits inside a MATLAB string literal.
    local path = vim.fn.expand("%:p"):gsub("'", "''")
    local matlab = ft == "matlab" and require("config.matlab").bin()
    if matlab then
      -- -batch (R2019a+): no desktop, no splash, exits non-zero on error
      return ("%s -batch %s"):format(vim.fn.shellescape(matlab), vim.fn.shellescape("run('" .. path .. "')"))
    elseif vim.fn.executable("octave") == 1 then
      return "octave --no-gui --quiet --eval " .. vim.fn.shellescape("run('" .. path .. "')")
    end
    vim.notify("Neither MATLAB nor Octave found (set g:matlab_install_path)", vim.log.levels.WARN)
    return nil
  elseif ft == "python" then
    -- The project's venv, not whatever python3 $PATH happens to point at
    return vim.fn.shellescape(require("config.venv").python(M.root()) or "python3") .. " " .. file
  elseif ft == "javascript" then
    return "node " .. file
  elseif ft == "typescript" or ft == "typescriptreact" or ft == "javascriptreact" then
    -- tsx strips types and runs in one step; node can do it natively from 22.6
    -- but only behind a flag, so prefer tsx when the project has it.
    return (vim.fn.executable("tsx") == 1 and "tsx " or "node --experimental-strip-types ") .. file
  elseif ft == "sh" or ft == "bash" then
    return "bash " .. file
  elseif ft == "lua" then
    -- nvim -l runs the file in Neovim's own LuaJIT, so this works even where no
    -- standalone lua interpreter is installed
    return "nvim -l " .. file
  end
  return nil
end

local term_win = nil
local last_cmd = nil
local last_root = nil

--- Run the current file in a terminal split, reusing one window across runs.
function M.run()
  -- Focus lands in the terminal after a run (a program reading stdin is
  -- useless otherwise), and a terminal buffer has no filetype to derive a
  -- command from. Falling back to the previous command makes <leader>br
  -- re-run in place, instead of demanding a trip back to the source window.
  -- The root is remembered with it: rederiving it from a term:// buffer name
  -- would silently run the repeat from a different directory.
  local cmd, root = run_cmd(), nil
  if cmd then
    root = M.root()
    if vim.bo.buftype == "" and not save("update") then return end
  else
    cmd, root = last_cmd, last_root
  end
  if not cmd then
    vim.notify("Nothing to run for filetype: " .. vim.bo.filetype, vim.log.levels.WARN)
    return
  end
  last_cmd, last_root = cmd, root

  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_set_current_win(term_win)
  else
    vim.cmd("botright 15split")
    term_win = vim.api.nvim_get_current_win()
  end
  -- A fresh buffer every time, and never the source buffer: jobstart(term=true)
  -- turns whatever buffer is current into the terminal, and a split starts out
  -- showing the file you just ran. Without this the source buffer itself
  -- becomes the terminal — taking its still-attached LSP client with it, which
  -- clangd reports as "only supports 'file' URI scheme".
  local previous = vim.api.nvim_get_current_buf()
  vim.cmd("enew")
  -- Each run leaves its finished terminal buffer behind; without this they pile
  -- up in :ls and the buffer picker for the rest of the session.
  if vim.api.nvim_buf_is_valid(previous) and vim.bo[previous].buftype == "terminal" then
    pcall(vim.api.nvim_buf_delete, previous, { force = true })
  end

  vim.fn.jobstart(cmd, { cwd = root, term = true })
  -- Terminal-mode keys (<Esc><Esc>, <C-h/j/k/l>, and <leader>br itself) come
  -- from the global TermOpen autocmd in lua/config/autocmds.lua.
  vim.cmd("startinsert") -- so a program that reads stdin is immediately usable
end

return M
