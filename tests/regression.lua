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
