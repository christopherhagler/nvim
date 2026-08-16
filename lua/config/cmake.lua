-- CMake project control: build type, target, and preset selection, plus the
-- target/artifact list the debugger launches from.
--
-- Why this exists at all: `cmake -S . -B build && cmake --build build` — what
-- <leader>bb used to run — configures with no CMAKE_BUILD_TYPE. On a
-- single-config generator that leaves CMAKE_<LANG>_FLAGS_<CONFIG> empty, so the
-- compiler is invoked with no -g and the binary carries no debug info at all.
-- Breakpoints then never bind, which reads as "the debugger is broken" rather
-- than "the build was wrong". Every IDE defaults to a Debug configuration for
-- exactly this reason, so Debug is the default here — and once there is a
-- default there has to be a way to change it, which is the rest of this file.
--
-- Target and artifact discovery goes through the CMake file API (v2, CMake
-- 3.14+; RHEL/Rocky 8 ships 3.20) rather than parsing `cmake --build . --target
-- help`. The file API is generator-independent — that help target does not
-- exist under Ninja — and, unlike any of the alternatives, it reports each
-- target's *output path*. That is what lets <F5> debug the thing you just built
-- instead of guessing at executables on disk (lua/plugins/dap.lua).

local M = {}

M.BUILD_TYPES = { "Debug", "RelWithDebInfo", "Release", "MinSizeRel" }

local function read_json(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  local ok, decoded = pcall(vim.json.decode, content)
  return ok and decoded or nil
end

-- ── Per-project profile ──────────────────────────────────────────────────────
-- Remembered across restarts, the way an IDE remembers its run configuration.
-- Keyed by project root, so a monorepo with several CMake trees keeps one
-- profile per tree.

local STATE = vim.fn.stdpath("state") .. "/cmake-profiles.json"
local profiles = nil

local function load()
  if profiles then return profiles end
  profiles = read_json(STATE) or {}
  if type(profiles) ~= "table" then profiles = {} end
  return profiles
end

local function save()
  vim.fn.mkdir(vim.fn.fnamemodify(STATE, ":h"), "p")
  local f = io.open(STATE, "w")
  if not f then return end
  f:write(vim.json.encode(profiles or {}))
  f:close()
end

--- The remembered profile for a project, created with IDE defaults if new.
--- @param root string|nil
--- @return table profile, string root
function M.profile(root)
  root = root or require("config.project").root()
  local all = load()
  if not all[root] then
    all[root] = { build_type = "Debug" } -- Debug: see the header comment
  end
  return all[root], root
end

--- Set one profile field and persist. `value = nil` clears it.
function M.set(key, value, root)
  local profile, r = M.profile(root)
  profile[key] = value
  load()[r] = profile
  save()
end

function M.is_cmake(root)
  root = root or require("config.project").root()
  return vim.uv.fs_stat(root .. "/CMakeLists.txt") ~= nil
end

-- ── CMakePresets.json ────────────────────────────────────────────────────────
-- Presets are how a modern C++ project shares one configuration between CI, the
-- command line and every editor, so a preset — when the project has one — wins
-- over the build type chosen here: it owns the build directory, the generator
-- and the cache variables.

--- Expand the preset macros that actually turn up in a binaryDir.
local function expand(str, ctx)
  if type(str) ~= "string" then return str end
  return (str
    :gsub("%$env{([^}]+)}", function(v) return vim.env[v] or "" end)
    :gsub("%$penv{([^}]+)}", function(v) return vim.env[v] or "" end)
    :gsub("%${(%w+)}", function(name) return ctx[name] or ("${" .. name .. "}") end))
end

local function preset_map(root)
  local map = {}
  for _, file in ipairs({ "CMakePresets.json", "CMakeUserPresets.json" }) do
    local data = read_json(root .. "/" .. file)
    if data and type(data.configurePresets) == "table" then
      for _, preset in ipairs(data.configurePresets) do
        if type(preset) == "table" and preset.name then map[preset.name] = preset end
      end
    end
  end
  return map
end

--- Resolved, absolute binaryDir of a configure preset (`inherits` followed).
local function preset_binary_dir(root, name)
  local map = preset_map(root)
  local seen = {}

  local function resolve(n)
    if not n or seen[n] or not map[n] then return nil end
    seen[n] = true
    if map[n].binaryDir then return map[n].binaryDir end
    local inherits = map[n].inherits
    if type(inherits) == "string" then inherits = { inherits } end
    for _, parent in ipairs(inherits or {}) do
      local found = resolve(parent)
      if found then return found end
    end
    return nil
  end

  -- CMake's own default when a preset omits binaryDir entirely.
  local dir = resolve(name) or "${sourceDir}/build/${presetName}"
  dir = expand(dir, {
    sourceDir       = root,
    sourceParentDir = vim.fs.dirname(root),
    sourceDirName   = vim.fs.basename(root),
    presetName      = name,
    hostSystemName  = vim.uv.os_uname().sysname,
    dollar          = "$",
  })
  if not vim.startswith(dir, "/") then dir = root .. "/" .. dir end
  return vim.fs.normalize(dir)
end

--- Configure presets available for this project, as CMake itself reports them
--- (so `condition` blocks and `hidden` presets are already filtered out).
function M.presets(root)
  root = root or require("config.project").root()
  if not vim.uv.fs_stat(root .. "/CMakePresets.json")
    and not vim.uv.fs_stat(root .. "/CMakeUserPresets.json") then
    return {}
  end
  if vim.fn.executable("cmake") == 0 then return {} end
  local res = vim.system({ "cmake", "--list-presets" }, { cwd = root, text = true }):wait()
  if res.code ~= 0 then return {} end
  local names = {}
  for line in (res.stdout or ""):gmatch("[^\n]+") do
    local name = line:match('^%s*"([^"]+)"') -- lines look like:   "debug" - Debug build
    if name then table.insert(names, name) end
  end
  return names
end

-- ── Build directory and generator shape ──────────────────────────────────────

function M.binary_dir(root)
  local profile, r = M.profile(root)
  if profile.preset then
    local dir = preset_binary_dir(r, profile.preset)
    if dir then return dir end
  end
  return r .. "/build"
end

-- Ninja Multi-Config and the VS generators pick the configuration at *build*
-- time, not configure time, so CMAKE_BUILD_TYPE is meaningless for them and
-- `--config` is required instead. The cache is the authority on which kind of
-- generator a build directory belongs to; before the first configure there is
-- no cache, and single-config is both the common case and the harmless guess
-- (a multi-config generator ignores CMAKE_BUILD_TYPE).
local function is_multi_config(build_dir)
  local f = io.open(build_dir .. "/CMakeCache.txt", "r")
  if not f then return false end
  local multi = false
  for line in f:lines() do
    local value = line:match("^CMAKE_CONFIGURATION_TYPES:[^=]*=(.*)$")
    if value then
      multi = value ~= ""
      break
    end
  end
  f:close()
  return multi
end

-- CMake only writes its machine-readable project description when a query file
-- exists *before* the configure step, so this has to run on the way in.
local function request_file_api(build_dir)
  local dir = build_dir .. "/.cmake/api/v1/query"
  vim.fn.mkdir(dir, "p")
  local path = dir .. "/codemodel-v2"
  if not vim.uv.fs_stat(path) then vim.fn.writefile({}, path) end
end

-- ── Command lines ────────────────────────────────────────────────────────────

--- argv for the configure step. Shared with :CompileCommands
--- (lua/config/compiledb.lua) so the two never fight over the cache by
--- configuring the same directory with different build types.
function M.configure_argv(root)
  local profile, r = M.profile(root)
  local build = M.binary_dir(r)
  request_file_api(build)

  local argv = { "cmake" }
  if profile.preset then
    -- Run from the project root (every caller does), which is where CMake
    -- looks for CMakePresets.json.
    vim.list_extend(argv, { "--preset", profile.preset })
  else
    vim.list_extend(argv, { "-S", r, "-B", build })
    if not is_multi_config(build) then
      table.insert(argv, "-DCMAKE_BUILD_TYPE=" .. profile.build_type)
    end
  end
  table.insert(argv, "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON")
  return argv, r
end

function M.build_argv(root)
  local profile, r = M.profile(root)
  local build = M.binary_dir(r)
  local argv = { "cmake", "--build", build }
  if is_multi_config(build) then
    vim.list_extend(argv, { "--config", profile.build_type })
  end
  if profile.target then
    vim.list_extend(argv, { "--target", profile.target })
  end
  -- Parallel by default; CMake gained --build -j in 3.12, well below the 3.20
  -- on RHEL/Rocky 8.
  vim.list_extend(argv, { "-j", tostring(math.max(1, vim.uv.available_parallelism() or 4)) })
  return argv
end

local function shell(argv)
  return table.concat(vim.tbl_map(vim.fn.shellescape, argv), " ")
end

--- Configure-then-build, as one shell command for lua/config/build.lua.
--- @return string cmd, string label
function M.build_cmd(root)
  local configure, r = M.configure_argv(root)
  local profile = M.profile(r)
  local label = "cmake " .. (profile.preset and ("preset " .. profile.preset) or profile.build_type)
  if profile.target then label = label .. " → " .. profile.target end
  return shell(configure) .. " && " .. shell(M.build_argv(r)), label
end

-- ── Targets, from the file API ───────────────────────────────────────────────

--- Every target of the configured project: name, CMake type, and the absolute
--- path of the artifact it produces (nil for targets that produce none).
--- Empty until the project has been configured at least once.
function M.targets(root)
  local profile, r = M.profile(root)
  local build = M.binary_dir(r)
  local reply = build .. "/.cmake/api/v1/reply"
  if not vim.uv.fs_stat(reply) then return {} end

  -- Each configure writes a fresh index and leaves the old ones; the name
  -- embeds a timestamp, so the highest-sorting one is current.
  local index_file
  for name, type_ in vim.fs.dir(reply) do
    if type_ == "file" and name:match("^index%-.*%.json$")
      and (not index_file or name > index_file) then
      index_file = name
    end
  end
  if not index_file then return {} end

  local index = read_json(reply .. "/" .. index_file)
  local entry = index and index.reply and index.reply["codemodel-v2"]
  local codemodel = entry and entry.jsonFile and read_json(reply .. "/" .. entry.jsonFile)
  if not codemodel or type(codemodel.configurations) ~= "table" then return {} end

  -- A multi-config build directory describes every configuration at once.
  local configuration = codemodel.configurations[1]
  for _, candidate in ipairs(codemodel.configurations) do
    if candidate.name == profile.build_type then
      configuration = candidate
      break
    end
  end
  if not configuration then return {} end

  local targets = {}
  for _, target in ipairs(configuration.targets or {}) do
    local detail = target.jsonFile and read_json(reply .. "/" .. target.jsonFile)
    local artifact = detail and detail.artifacts and detail.artifacts[1] and detail.artifacts[1].path
    table.insert(targets, {
      name = target.name,
      type = (detail and detail.type) or "UNKNOWN",
      path = artifact and vim.fs.normalize(build .. "/" .. artifact) or nil,
    })
  end
  table.sort(targets, function(a, b) return a.name < b.name end)
  return targets
end

--- Just the runnable targets, newest-built first — the list <F5> offers.
function M.executables(root)
  local exes = vim.tbl_filter(function(t)
    return t.type == "EXECUTABLE" and t.path and vim.uv.fs_stat(t.path) ~= nil
  end, M.targets(root))
  table.sort(exes, function(a, b)
    local sa = vim.uv.fs_stat(a.path)
    local sb = vim.uv.fs_stat(b.path)
    return (sa and sa.mtime.sec or 0) > (sb and sb.mtime.sec or 0)
  end)
  return exes
end

-- ── Pickers ──────────────────────────────────────────────────────────────────

local ALL_TARGETS = "<all targets>"

local function cmake_root()
  local root = require("config.project").root()
  if not M.is_cmake(root) then
    vim.notify("Not a CMake project: no CMakeLists.txt in " .. root, vim.log.levels.WARN)
    return nil
  end
  return root
end

function M.select_build_type()
  local root = cmake_root()
  if not root then return end
  vim.ui.select(M.BUILD_TYPES, { prompt = "CMake build type:" }, function(choice)
    if not choice then return end
    M.set("build_type", choice, root)
    vim.notify("CMake build type: " .. choice .. " (rebuild to apply)")
  end)
end

function M.select_target()
  local root = cmake_root()
  if not root then return end
  local targets = M.targets(root)
  if #targets == 0 then
    vim.notify("No targets known yet — build once (<leader>bb) so CMake can report them",
      vim.log.levels.WARN)
    return
  end

  local items, labels = { ALL_TARGETS }, {}
  for _, target in ipairs(targets) do
    table.insert(items, target.name)
    labels[target.name] = ("%s  (%s)"):format(target.name, target.type:lower():gsub("_", " "))
  end

  vim.ui.select(items, {
    prompt = "CMake target to build:",
    format_item = function(item) return labels[item] or item end,
  }, function(choice)
    if not choice then return end
    M.set("target", choice ~= ALL_TARGETS and choice or nil, root)
    vim.notify("CMake target: " .. choice)
  end)
end

function M.select_preset()
  local root = cmake_root()
  if not root then return end
  local presets = M.presets(root)
  if #presets == 0 then
    vim.notify("No CMakePresets.json in " .. root, vim.log.levels.WARN)
    return
  end
  local NONE = "<no preset — use the build type above>"
  local items = vim.list_extend({ NONE }, presets)
  vim.ui.select(items, { prompt = "CMake configure preset:" }, function(choice)
    if not choice then return end
    M.set("preset", choice ~= NONE and choice or nil, root)
    vim.notify("CMake preset: " .. choice)
  end)
end

--- One line describing what <leader>bb would do, for :CMakeStatus.
function M.status(root)
  local profile, r = M.profile(root)
  if not M.is_cmake(r) then return "Not a CMake project (" .. r .. ")" end
  local parts = {}
  if profile.preset then
    table.insert(parts, "preset " .. profile.preset)
  else
    table.insert(parts, profile.build_type)
  end
  table.insert(parts, profile.target and ("target " .. profile.target) or "all targets")
  table.insert(parts, "build dir " .. M.binary_dir(r))
  local exes = M.executables(r)
  table.insert(parts, #exes .. " runnable target(s)")
  return table.concat(parts, "\n  ")
end

return M
