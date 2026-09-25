-- CUDA toolkit discovery, shared by clangd (lua/config/compiledb.lua), the
-- single-file build (lua/config/build.lua), cuda-gdb (lua/plugins/dap.lua) and
-- header lookup for gf (lua/config/cfamily.lua).
--
-- The toolkit is rarely on $PATH on RHEL/Rocky: the NVIDIA repo installs it to
-- /usr/local/cuda-<ver> with a /usr/local/cuda symlink, and leaves adding bin/
-- to the user. So `nvcc` on $PATH is one signal among several, not the test.
-- macOS has had no CUDA toolkit since 10.13; everything here returns nil there
-- and the callers degrade to plain C++ handling.

local M = {}

local home_cache = nil

--- Root of the CUDA toolkit, or nil if none is installed.
--- @return string|nil
function M.home()
  if home_cache ~= nil then return home_cache or nil end

  local candidates = { vim.g.cuda_home, vim.env.CUDA_HOME, vim.env.CUDA_PATH, vim.env.CUDA_ROOT }
  -- nvcc on $PATH, resolved through symlinks: bin/nvcc → the toolkit root
  local nvcc = vim.fn.exepath("nvcc")
  if nvcc ~= "" then
    table.insert(candidates, vim.fn.fnamemodify(vim.fn.resolve(nvcc), ":h:h"))
  end
  table.insert(candidates, "/usr/local/cuda")
  -- No symlink (it is optional in the NVIDIA repo): newest versioned install
  local versioned = vim.fn.glob("/usr/local/cuda-*", false, true)
  table.sort(versioned, function(a, b) return vim.version.lt(a:match("[%d.]+$") or "0", b:match("[%d.]+$") or "0") end)
  table.insert(candidates, versioned[#versioned])

  for _, dir in ipairs(candidates) do
    if dir and dir ~= "" and vim.uv.fs_stat(dir .. "/bin/nvcc") then
      home_cache = vim.fn.resolve(dir)
      return home_cache
    end
  end
  home_cache = false
  return nil
end

--- A binary from the toolkit (nvcc, cuda-gdb), preferring $PATH.
--- @param name string
--- @return string|nil
function M.bin(name)
  local onpath = vim.fn.exepath(name)
  if onpath ~= "" then return onpath end
  local home = M.home()
  if home and vim.fn.executable(home .. "/bin/" .. name) == 1 then
    return home .. "/bin/" .. name
  end
  return nil
end

--- The .clangd fragment that lets clangd parse .cu/.cuh files.
---
--- clangd parses CUDA with clang's own frontend, not nvcc's. Two things break
--- without this: clang cannot find the toolkit unless it sits at /usr/local/cuda
--- (and even then, a toolkit newer than clangd's clang knows is a hard error),
--- and compile_commands.json from a CMake/nvcc build is full of nvcc-only flags
--- that clang rejects, each one an error on line 1 of every .cu file.
---
--- Scoped by PathMatch so it never touches the flags of C or C++ files.
--- @return string[] lines
function M.clangd_fragment()
  local add = { "--no-cuda-version-check", "-Wno-unknown-cuda-version" }
  local home = M.home()
  if home then table.insert(add, 1, "--cuda-path=" .. home) end
  return {
    "---",
    "# CUDA: clang's CUDA frontend in place of nvcc's (written by :CompileCommands)",
    "If:",
    [==[  PathMatch: ['.*\.cu', '.*\.cuh']]==],
    "CompileFlags:",
    "  Add: [" .. table.concat(add, ", ") .. "]",
    -- Prefix forms (trailing *) catch the joined `-flag=value` spelling CMake
    -- emits. -x is a real clang flag, so removing it also drops its `cu`
    -- argument, which clang does not recognise as a language.
    "  Remove: [-forward-unknown-to-host-compiler, --generate-code*, -gencode*, -arch*, --gpu-architecture*,"
      .. " -rdc*, --relocatable-device-code*, -Xcompiler*, -Xptxas*, -Xfatbin*, -Xcudafe*, -Xnvlink*,"
      .. " --expt-relaxed-constexpr, --expt-extended-lambda, --extended-lambda, --use_fast_math,"
      .. " -ccbin*, --compiler-bindir*, --diag-suppress*, --diag_suppress*, -x]",
  }
end

return M
