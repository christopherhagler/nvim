-- Dependency-free integration checks; run with bash tests/run.sh.
vim.opt.rtp:prepend(vim.fn.getcwd())
local repo = vim.fn.getcwd()
local fixture = vim.fn.tempname()
fixture = vim.uv.fs_realpath(vim.fs.dirname(fixture)) .. "/" .. vim.fs.basename(fixture)
local messages = {}
vim.notify = function(msg) messages[#messages + 1] = msg end
local function equal(actual, expected)
  assert(vim.deep_equal(actual, expected), vim.inspect(actual) .. " ~= " .. vim.inspect(expected))
end
local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines or {}, path)
end
local function edit(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
end
local function test()
  for _, file in ipairs(vim.fn.glob("lua/**/*.lua", false, true)) do assert(loadfile(file)) end
  local a, b = fixture .. "/project a", fixture .. "/project b"
  write(a .. "/.git/HEAD")
  write(b .. "/.git/HEAD")
  write(a .. "/src/main.c", { "int main(void) { return 0; }" })
  write(a .. "/src/CMakeLists.txt")
  write(a .. "/CMakeLists.txt")
  write(b .. "/main.py", { "print('hello')" })
  vim.cmd.cd(vim.fn.fnameescape(a))
  local project = require("config.project")
  equal(project.root(a .. "/src/main.c"), a)
  equal(project.root(b .. "/main.py"), b)
  vim.g.build_cmd = "legacy-a"
  equal(project.get("build_cmd", a), "legacy-a")
  equal(project.get("build_cmd", b), nil)
  project.setup({ build_cmd = "scoped-b", run_cmd = "run-b", notrim = false }, b)
  equal(project.get("build_cmd", b), "scoped-b")
  equal(project.get("notrim", b), false)

  -- Interpreter selection follows the buffer even with another cwd.
  write(b .. "/.venv/bin/python", { "#!/bin/sh", "exit 0" })
  vim.fn.setfperm(b .. "/.venv/bin/python", "rwx------")
  vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX = nil, nil
  edit(b .. "/main.py")
  equal(require("config.venv").python(), b .. "/.venv/bin/python")
  equal(require("config.build").build_cmd(), "scoped-b")

  -- Search mappings resolve the project at invocation, not plugin load.
  local picked
  package.loaded["telescope.builtin"] = setmetatable({}, {
    __index = function(_, name) return function(opts) picked = { name, opts.cwd } end end,
  })
  local telescope = dofile(repo .. "/lua/plugins/telescope.lua")[1]
  for _, key in ipairs(telescope.keys) do
    if key[1] == "<leader>fg" then key[2]() end
  end
  equal(picked, { "live_grep", b })

  -- clangd resolves project flags before spawning, independently per client.
  package.loaded["blink.cmp"] = { get_lsp_capabilities = function() return {} end }
  package.loaded["schemastore"] = { json = { schemas = function() return {} end } }
  package.loaded["mason-lspconfig"] = { setup = function() end }
  local lsp = dofile(repo .. "/lua/plugins/lsp.lua")
  lsp[3].config()
  project.setup({ clangd_query_driver = "/toolchain/a-*" }, a)
  project.setup({ clangd_query_driver = "" }, b)
  local rpc_start, spawned = vim.lsp.rpc.start, {}
  vim.lsp.rpc.start = function(cmd)
    spawned[#spawned + 1] = cmd
    return {}
  end
  vim.lsp.config.clangd.cmd({}, { root_dir = a })
  vim.lsp.config.clangd.cmd({}, { root_dir = b })
  vim.lsp.rpc.start = rpc_start
  assert(vim.tbl_contains(spawned[1], "--query-driver=/toolchain/a-*"))
  for _, arg in ipairs(spawned[2]) do assert(not arg:find("--query-driver=", 1, true)) end

  -- Real async build: changing cwd before completion must not change paths.
  edit(a .. "/src/main.c")
  local build = require("config.build")
  local callback = false
  local output = "src/main.c:1:2: warning: root warning\n"
    .. "make[1]: Entering directory '" .. a .. "/src'\n"
    .. "main.c:1:3: warning: nested warning\n"
    .. "make[1]: Leaving directory '" .. a .. "/src'\n"
  build.build("printf %s " .. vim.fn.shellescape(output), function() callback = true end)
  vim.cmd.cd(vim.fn.fnameescape(b))
  assert(vim.wait(5000, function() return callback end), "build callback timed out")
  local valid = vim.tbl_filter(function(item) return item.valid == 1 end, vim.fn.getqflist())
  equal(#valid, 2)
  for _, item in ipairs(valid) do equal(vim.api.nvim_buf_get_name(item.bufnr), a .. "/src/main.c") end
  equal(vim.fn.getcwd(), b)

  -- A write handler that leaves changes unsaved must also abort the build.
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "modified" })
  local handler = vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = 0, callback = function() end,
  })
  local original_system = vim.system
  vim.system = function() error("process launched with unsaved changes") end
  build.build("true")
  vim.system = original_system
  assert(messages[#messages]:find("unsaved changes", 1, true))
  vim.api.nvim_del_autocmd(handler)
  vim.bo.modified = false

  -- Write failure must prevent both build and run from launching a process.
  vim.cmd.enew()
  vim.api.nvim_buf_set_name(0, fixture .. "/missing/directory/broken.py")
  vim.bo.filetype = "python"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
  local system = vim.system
  vim.system = function() error("process launched despite save failure") end
  build.build("true", function() error("debug callback ran despite save failure") end)
  build.run()
  vim.system = system
  assert(vim.bo.modified)
  assert(messages[#messages]:find("Save failed", 1, true))
  vim.bo.modified = false

  -- MATLAB stack locations retain hyperlink paths (including spaces) and
  -- plain stacks resolve against the project, independently of the cwd.
  write(a .. "/failure.m", { "error('failed')" })
  local errors = require("config.matlab_errors")
  local trace = "Error in <a href=\"matlab: opentoline('" .. a .. "/failure.m',12,0)\">failure (line 12)</a>\n"
    .. "Error in failure (line 12)\n"
    .. "Error in missing_function (line 3)\n"
  local parsed = errors.parse(trace, a)
  equal(#parsed, 1)
  equal(parsed[1].filename, a .. "/failure.m")
  equal(parsed[1].lnum, 12)
  equal(#errors.parse("ordinary output", a), 0)
  equal(errors.parse("Error: File: " .. a .. "/failure.m Line: 1 Column: 2", a)[1].lnum, 1)

  -- Stream fragments must be assembled before parsing, and silent housekeeping
  -- responses must not consume the active evaluation's trace.
  local session = require("config.matlab_session")
  local get_clients, get_client = vim.lsp.get_clients, vim.lsp.get_client_by_id
  local sent = {}
  local fake = { id = 987, config = { root_dir = a }, notify = function(_, method, params)
    sent[#sent + 1] = { method, params }
  end }
  vim.lsp.get_clients = function() return { fake } end
  vim.lsp.get_client_by_id = function() return fake end
  session.handlers.mvmStateChange(nil, { state = "connected" }, { client_id = fake.id })
  session.eval("failure")
  local request_id = sent[#sent][2].requestId
  session.handlers.text(nil, { text = trace:sub(1, 30) })
  session.handlers.evalResponse(nil, { requestId = -1 })
  session.handlers.text(nil, { text = trace:sub(31) })
  session.handlers.evalResponse(nil, { requestId = request_id })
  equal(vim.fn.getqflist({ title = 0 }).title, "MATLAB runtime errors")
  equal(#vim.fn.getqflist(), 1)
  equal(vim.api.nvim_buf_get_name(vim.fn.getqflist()[1].bufnr), a .. "/failure.m")
  session.handlers.mvmStateChange(nil, { state = "disconnected" }, { client_id = fake.id })
  vim.lsp.get_clients, vim.lsp.get_client_by_id = get_clients, get_client
  vim.cmd("silent! only")

  -- The command window survives closing/reopening and submits to the shared
  -- session. Exercise the actual prompt callback and command recall mappings.
  local session = require("config.matlab_session")
  local eval, submitted = session.eval, {}
  session.eval = function(code) submitted[#submitted + 1] = code end
  local console = require("config.matlab_console")
  console.open()
  local command_buf = vim.api.nvim_get_current_buf()
  equal(vim.bo.buftype, "prompt")
  vim.api.nvim_feedkeys(vim.keycode("iwhos<CR><Esc>"), "xt", false)
  equal(submitted, { "whos" })
  vim.cmd.close()
  console.open()
  equal(vim.api.nvim_get_current_buf(), command_buf)
  vim.api.nvim_feedkeys(vim.keycode("i<Up><CR><Esc>"), "xt", false)
  equal(submitted, { "whos", "whos" })
  session.eval = eval
  vim.cmd.close()

  -- Recursive Make: a subdirectory's own Makefile does not make it the project.
  local mk = fixture .. "/make tree"
  write(mk .. "/.git/HEAD")
  write(mk .. "/Makefile")
  write(mk .. "/drivers/Makefile")
  write(mk .. "/drivers/foo.c")
  equal(project.root(mk .. "/drivers/foo.c"), mk)

  -- Build output is typed: errors and warnings counted apart, notes neither.
  edit(a .. "/src/main.c")
  local built = false
  build.build("printf '%s\\n' 'main.c:1:1: error: bad' 'main.c:2:1: warning: meh' 'main.c:3:1: note: here'"
    .. " 'collect2: error: ld returned 1 exit status'; exit 2")
  assert(vim.wait(5000, function() return messages[#messages]:find("Build failed", 1, true) ~= nil end))
  assert(messages[#messages]:find("1 error(s), 1 warning(s)", 1, true), messages[#messages])
  local types = vim.tbl_map(function(i) return i.type end,
    vim.tbl_filter(function(i) return i.valid == 1 end, vim.fn.getqflist()))
  equal(types, { "e", "w", "" })
  -- The failure opened quickfix (the unparsed linker line is in it as text);
  -- the next successful build closes that window, and only that one.
  local function qf_open()
    return vim.iter(vim.fn.getwininfo()):any(function(w) return w.quickfix == 1 end)
  end
  assert(qf_open())
  build.build("true", function() built = true end)
  assert(vim.wait(5000, function() return built end))
  assert(not qf_open())
  vim.fn.setqflist({}, " ", { title = "grep results", lines = { "x" } })
  vim.cmd("copen")
  built = false
  build.build("true", function() built = true end)
  assert(vim.wait(5000, function() return built end))
  assert(qf_open(), "a quickfix window the user opened was closed by a build")
  vim.cmd("cclose")

  -- Commands built in a project are kept, most recent first.
  equal(build.history(a)[1], "true")
  assert(vim.tbl_contains(build.history(a), "printf %s " .. vim.fn.shellescape(output)))

  -- A remembered command beats .nvim.lua's build_cmd, and resetting restores it.
  edit(b .. "/main.py")
  build.remember("make image", b)
  equal({ build.build_cmd() }, { "make image", "remembered" })
  build.remember(nil, b)
  equal(build.build_cmd(), "scoped-b")

  -- :Build appends like :make; the same program, or a bang, replaces.
  local ran = {}
  local real_build = build.build
  build.build = function(cmd) ran[#ran + 1] = cmd end
  build.remember("gmake -j4 ARCH=arm64", b)
  build.build_args("image", false)
  build.build_args("gmake clean", false)
  build.build_args("./release.sh", true)
  build.remember("'cmake' '-S' . && 'cmake' '--build' 'out'", b)
  build.build_args("cmake --build out --target tool", false)
  build.remember(nil, b)
  build.build = real_build
  equal(ran, {
    "gmake -j4 ARCH=arm64 image",
    "gmake clean",
    "./release.sh",
    "'cmake' '-S' . && cmake --build out --target tool",
  })

  -- Make's database dump: real targets only.
  equal(require("config.make")._parse(table.concat({
    "# Files", "", "# Not a target:", "foo.c:", "", "all: build", "", "image: build", "",
    "obj/%.o: src/%.c", "", ".PHONY: all", "", "Makefile:", "", "extra.mk:", "", "CC := gcc", "",
    "# Finished Make data base",
  }, "\n")), { "all", "image" })

  -- CMake: a build directory configured by hand keeps its build type until one
  -- is chosen with <leader>bt.
  local cm = fixture .. "/cmake tree"
  write(cm .. "/.git/HEAD")
  write(cm .. "/CMakeLists.txt")
  write(cm .. "/build/CMakeCache.txt", { "CMAKE_BUILD_TYPE:STRING=Release" })
  local cmake = require("config.cmake")
  equal({ cmake.build_type(cm) }, { "Release", false })
  local function passes_type(argv)
    return vim.iter(argv):any(function(arg) return arg:find("^%-DCMAKE_BUILD_TYPE=") ~= nil end)
  end
  assert(not passes_type(cmake.configure_argv(cm)))
  cmake.set("build_type", "Debug", cm)
  assert(vim.tbl_contains(cmake.configure_argv(cm), "-DCMAKE_BUILD_TYPE=Debug"))

  -- A CMake build that creates the first compile database restarts clangd
  -- (it never rescans for one) and links it into the root; later builds,
  -- whose database clangd already watches, leave it running.
  local compiledb = require("config.compiledb")
  local cmd, get_clients, restarts = vim.cmd, vim.lsp.get_clients, 0
  vim.lsp.get_clients = function() return { {} } end
  vim.cmd = function(c) if c == "lsp restart clangd" then restarts = restarts + 1 end end
  local stubbed_ok, stubbed_err = pcall(function()
    equal(compiledb.cmake_db_exists(a), false)
    write(a .. "/build/compile_commands.json", { "[]" })
    compiledb.after_cmake_build(a, false)
    compiledb.after_cmake_build(a, true)
  end)
  vim.cmd, vim.lsp.get_clients = cmd, get_clients
  assert(stubbed_ok, stubbed_err)
  equal(restarts, 1)
  equal(vim.uv.fs_readlink(a .. "/compile_commands.json"), a .. "/build/compile_commands.json")

  -- Recovery protections use central directories and retain the old undo path.
  require("config.options")
  assert(vim.o.swapfile and vim.o.writebackup and vim.o.undofile)
  assert(vim.fn.isdirectory(vim.fn.stdpath("state") .. "/swap") == 1)
  equal(vim.o.undodir, vim.fn.stdpath("data") .. "/undodir")
  print("All regression checks passed")
end
local ok, err = xpcall(test, debug.traceback)
vim.cmd.cd(vim.fn.fnameescape(repo))
vim.fn.delete(fixture, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
