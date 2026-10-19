-- Make: which binary, which flags, and which targets a Makefile offers.
--
-- Bare `make` is the wrong default for a real tree: it builds one file at a
-- time, and a parallel build without output sync interleaves the recursive
-- "Entering directory" lines that quickfix uses to resolve relative paths. GNU
-- make 4+ has --output-sync; macOS still ships 3.81 as /usr/bin/make, so a
-- Homebrew gmake is preferred there. EL8 has 4.2.1 and EL9 4.3.

local M = {}

local program_cache = nil

local function major_version(bin)
  local res = vim.system({ bin, "--version" }, { text = true }):wait(2000)
  return tonumber((res.stdout or ""):match("GNU Make (%d+)")) or 0
end

--- The make binary to use and its GNU major version (0 if not GNU make).
--- @return string program, integer major
function M.program()
  if program_cache then return program_cache[1], program_cache[2] end
  local bin, major = "make", major_version("make")
  if major < 4 and vim.fn.executable("gmake") == 1 then
    local g = major_version("gmake")
    if g >= 4 then bin, major = "gmake", g end
  end
  program_cache = { bin, major }
  return bin, major
end

--- The command <leader>bb runs in a Make project with nothing remembered.
--- Parallel unless $MAKEFLAGS already says how many jobs (a jobserver from an
--- outer make, or the user's own choice). A project whose Makefile is not
--- parallel-safe remembers plain `make` with <leader>bc.
function M.command()
  local bin, major = M.program()
  local parts = { bin }
  local makeflags = vim.env.MAKEFLAGS or ""
  if not (makeflags:find("%-j") or makeflags:find("jobs")) then
    table.insert(parts, "-j" .. math.max(1, vim.uv.available_parallelism() or 4))
    -- Each target's output in one piece, so the directory stack stays intact
    if major >= 4 then table.insert(parts, "--output-sync=target") end
  end
  return table.concat(parts, " ")
end

function M.is_make(root)
  for _, name in ipairs({ "Makefile", "makefile", "GNUmakefile" }) do
    if vim.uv.fs_stat(root .. "/" .. name) then return true end
  end
  return false
end

--- VAR=value words of a command line (ARCH=arm64 CROSS_COMPILE=…), which
--- change the targets a Makefile defines and so must reach the listing too.
function M.variables(cmd)
  local vars = {}
  for word in (cmd or ""):gmatch("%S+") do
    if word:match("^[%a_][%w_]*=") then table.insert(vars, word) end
  end
  return vars
end

-- ── Targets ──────────────────────────────────────────────────────────────────
--
-- From make's own database rather than a regex over the Makefile, so targets
-- from include'd and generated makefiles — where kernel and embedded targets
-- live — are listed. -p prints the database; -n/-q build nothing; -R/-r drop
-- the built-in rules and variables, which keeps the dump small; the goal `:`
-- matches no target. GNU make still remakes out-of-date included makefiles
-- even then, which is why this never runs on its own: only when you ask for a
-- target list, and bounded by a timeout.

local TIMEOUT_MS = 15000
local cache = {} -- root → { key = makefile mtime .. vars, targets = {...} }

local function cache_key(root, vars)
  local stat = vim.uv.fs_stat(root .. "/Makefile") or vim.uv.fs_stat(root .. "/makefile")
    or vim.uv.fs_stat(root .. "/GNUmakefile")
  return (stat and stat.mtime.sec or 0) .. "|" .. table.concat(vars, " ")
end

local function parse(dump)
  local targets, seen = {}, {}
  local in_files, skip = false, false
  for _, line in ipairs(vim.split(dump, "\n", { plain = true })) do
    if line:match("^# Files") then
      in_files = true
    elseif line:match("^# Finished Make data base") then
      break
    elseif in_files then
      if line:match("^# Not a target") then
        skip = true
      elseif line == "" then
        skip = false
      elseif not skip then
        local name = line:match("^([^#%s:=][^:=%s]*):")
        -- Pattern rules, paths (object files, generated headers), special and
        -- hidden targets, and variable assignments are not things you build
        -- (and the makefiles themselves, which make lists as remakeable)
        if name and not name:find("[%%/=$]") and not name:match("^%.")
          and not name:match("%.mk$") and not name:match("^[GNU]*[Mm]akefile$")
          and not line:match("^[^:]+:[:!]?=") and not seen[name] then
          seen[name] = true
          table.insert(targets, name)
        end
      end
    end
  end
  table.sort(targets)
  return targets
end

local function argv(vars)
  local bin = M.program()
  return vim.list_extend({ bin, "-pRrnq" }, vim.list_extend(vim.deepcopy(vars), { ":" }))
end

--- List the Makefile's targets asynchronously.
--- @param root string
--- @param vars string[] VAR=value words
--- @param callback fun(targets: string[]|nil, err: string|nil)
function M.targets(root, vars, callback)
  local key = cache_key(root, vars)
  if cache[root] and cache[root].key == key then return callback(cache[root].targets) end
  vim.system(argv(vars), { cwd = root, text = true, timeout = TIMEOUT_MS }, vim.schedule_wrap(function(res)
    -- -q exits 1 ("not up to date") on a perfectly good dump; only the
    -- absence of a database means failure
    local targets = parse(res.stdout or "")
    if #targets == 0 then
      return callback(nil, res.signal ~= 0 and "timed out" or vim.trim(res.stderr or ""))
    end
    cache[root] = { key = key, targets = targets }
    callback(targets)
  end))
end

--- Cached target list for command-line completion, which cannot wait: listed
--- synchronously (briefly) the first time, from the cache afterwards.
function M.targets_sync(root, vars)
  local key = cache_key(root, vars)
  if cache[root] and cache[root].key == key then return cache[root].targets end
  local ok, res = pcall(function()
    return vim.system(argv(vars), { cwd = root, text = true }):wait(3000)
  end)
  if not ok or not res then return {} end
  local targets = parse(res.stdout or "")
  if #targets > 0 then cache[root] = { key = key, targets = targets } end
  return targets
end

M._parse = parse

return M
