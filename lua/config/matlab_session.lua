-- One MATLAB, running in the background, shared by everything MATLAB-related.
--
-- matlab_ls already launches a headless MATLAB and keeps it alive — that is
-- where its diagnostics and navigation come from. The same server also accepts
-- code to evaluate in that MATLAB and streams the output back, over custom LSP
-- notifications (evalRequest / text / evalResponse, the channel MathWorks' VS
-- Code extension uses for its terminal). So there is no second MATLAB to start
-- and no 10–15 s cold start per run: code runs in a session that is already
-- warm, whose workspace survives between runs, and whose path the project's
-- own setup has already configured (setup_project below). The debugger
-- attaches to this same session (lua/config/matlab_dap.lua).
--
-- Handlers for the server's notifications are installed on the matlab_ls
-- client in lua/plugins/lsp.lua.

local M = {}

local state = {
  connected = false,
  prompt = nil,       -- READY / BUSY / DEBUG / INPUT …, from mvmPromptChange
  setup_done = {},    -- client id → true once the project setup has run
  pending = {},       -- requestId → on_done callback
  waiting = {},       -- callbacks queued until MATLAB connects
  next_id = 0,
  bridge = nil,       -- the active debug session, if any (matlab_dap.lua)
  out_buf = nil,
  out_win = nil,
}

-- ── Output window ────────────────────────────────────────────────────────────

local function output_buf()
  if state.out_buf and vim.api.nvim_buf_is_valid(state.out_buf) then return state.out_buf end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "matlab://output")
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = "matlab-output"
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close MATLAB output" })
  state.out_buf = buf
  return buf
end

--- Show the output window (reusing it if open) without taking focus.
function M.show_output()
  local buf = output_buf()
  if state.out_win and vim.api.nvim_win_is_valid(state.out_win) then return end
  local prev = vim.api.nvim_get_current_win()
  vim.cmd("botright 12split")
  state.out_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.out_win, buf)
  vim.wo[state.out_win].number = false
  vim.wo[state.out_win].relativenumber = false
  vim.wo[state.out_win].signcolumn = "no"
  vim.wo[state.out_win].wrap = true
  vim.api.nvim_set_current_win(prev)
end

function M.toggle_output()
  if state.out_win and vim.api.nvim_win_is_valid(state.out_win) then
    vim.api.nvim_win_close(state.out_win, false)
    state.out_win = nil
  else
    M.show_output()
  end
end

-- MATLAB decorates text for its own desktop: errors come wrapped in {\b … }\b
-- (its "print in red" markers) and stack lines carry <a href="matlab:…"> links.
local function clean(text)
  return (text:gsub("{\b", ""):gsub("}\b", ""):gsub("<a [^>]*>", ""):gsub("</a>", ""))
end

local function append(text)
  local buf = output_buf()
  local lines = vim.split(text, "\n", { plain = true })
  local last = vim.api.nvim_buf_line_count(buf)
  local tail = vim.api.nvim_buf_get_lines(buf, last - 1, last, false)[1] or ""
  -- The first chunk continues the last line; MATLAB sends partial lines
  lines[1] = tail .. lines[1]
  vim.api.nvim_buf_set_lines(buf, last - 1, last, false, lines)
  if state.out_win and vim.api.nvim_win_is_valid(state.out_win) then
    vim.api.nvim_win_set_cursor(state.out_win, { vim.api.nvim_buf_line_count(buf), 0 })
  end
end

-- ── Client and evaluation ────────────────────────────────────────────────────

local function client()
  return vim.lsp.get_clients({ name = "matlab_ls", bufnr = 0 })[1]
    or vim.lsp.get_clients({ name = "matlab_ls" })[1]
end

--- Run `fn` once MATLAB is connected and the project path is set up.
local function when_ready(fn)
  local c = client()
  if not c then
    vim.notify("MATLAB language server is not running (open a .m file first)", vim.log.levels.WARN)
    return
  end
  if state.connected and state.setup_done[c.id] then return fn(c) end
  if not require("config.matlab").install_path() then
    vim.notify("No MATLAB install found (set g:matlab_install_path)", vim.log.levels.ERROR)
    return
  end
  vim.notify("Waiting for MATLAB to start…", vim.log.levels.INFO)
  table.insert(state.waiting, fn)
end

--- Evaluate MATLAB code in the background session.
--- @param code string may span several lines
--- @param opts? { echo?: boolean, silent?: boolean, on_done?: fun() }
---   echo: print `>> code` in the output first; silent: not a user eval (no
---   output, no breakpoints — used for housekeeping like dbclear)
function M.eval(code, opts)
  opts = opts or {}
  when_ready(function(c)
    state.next_id = state.next_id + 1
    local id = state.next_id
    state.pending[id] = opts.on_done or false
    if opts.echo ~= false and not opts.silent then
      local first = vim.split(code, "\n")[1]
      local line = ">> " .. first .. (code:find("\n") and " …" or "") .. "\n"
      -- Same destination as the output that follows: dap-ui's REPL during a
      -- debug session, the output window otherwise
      if state.bridge then
        state.bridge.output(line, "console")
      else
        M.show_output()
        append(line)
      end
    end
    c:notify("evalRequest", { requestId = id, command = code, isUserEval = not opts.silent })
  end)
end

--- Ctrl-C for the background MATLAB.
function M.interrupt()
  local c = client()
  if c then c:notify("interruptRequest", {}) end
end

--- The MATLAB-literal form of a path ('' escapes a quote).
function M.quote(path)
  return "'" .. path:gsub("'", "''") .. "'"
end

--- Run a file the way the editor's Run button does. run() cds into the file's
--- folder while it executes, so the script's own neighbours resolve.
function M.run_file(path, opts)
  path = path or vim.fn.expand("%:p")
  if vim.bo.modified then vim.cmd("silent! write") end
  M.eval("run(" .. M.quote(path) .. ")", opts)
end

--- Run the %% section under the cursor (the whole file if it has none).
function M.run_section()
  local marker = [[^\s*%%\(\s\|$\)]]
  local first = vim.fn.search(marker, "bcnW")
  local next_ = vim.fn.search(marker, "nW")
  local s = first > 0 and first or 1
  local e = next_ > 0 and next_ - 1 or vim.fn.line("$")
  M.eval(table.concat(vim.api.nvim_buf_get_lines(0, s - 1, e, false), "\n"))
end

--- Run the lines covered by the visual selection.
function M.run_selection()
  local s, e = vim.fn.line("v"), vim.fn.line(".")
  if s > e then s, e = e, s end
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  M.eval(table.concat(vim.api.nvim_buf_get_lines(0, s - 1, e, false), "\n"))
end

-- ── Figures ──────────────────────────────────────────────────────────────────
--
-- The background MATLAB runs with graphics enabled (-nodesktop, not
-- -nodisplay), so plot/surf/imagesc/… open ordinary interactive figure windows
-- wherever a display exists: macOS, a Linux desktop, or an `ssh -Y` session.
-- Over plain SSH there is no display; MATLAB still renders figures, just
-- invisibly, so this exports them as images to look at by other means.

local FIG_DIR = vim.fn.stdpath("cache") .. "/matlab-figures"

--- Export every open figure to PNG, then open them in the system viewer when
--- there is a display, or list the files when there is not.
function M.export_figures()
  vim.fn.delete(FIG_DIR, "rf")
  vim.fn.mkdir(FIG_DIR, "p")
  local code = table.concat({
    "figs__ = findall(groot, 'Type', 'figure');",
    "for k__ = 1:numel(figs__)",
    "  f__ = figs__(k__); n__ = f__.Number; if isempty(n__), n__ = k__; end",
    "  p__ = fullfile(" .. M.quote(FIG_DIR) .. ", sprintf('figure_%d.png', n__));",
    -- exportgraphics (R2020a+) crops to content; print is the older fallback
    "  try, exportgraphics(f__, p__, 'Resolution', 150); catch, print(f__, p__, '-dpng', '-r150'); end",
    "end",
    "clear figs__ k__ f__ n__ p__",
  }, "\n")
  M.eval(code, {
    echo = false,
    on_done = function()
      local files = vim.fn.glob(FIG_DIR .. "/*.png", false, true)
      if #files == 0 then
        vim.notify("No open MATLAB figures", vim.log.levels.INFO)
        return
      end
      local has_display = vim.fn.has("mac") == 1 or vim.env.DISPLAY or vim.env.WAYLAND_DISPLAY
      local opener = vim.fn.has("mac") == 1 and "open" or "xdg-open"
      if has_display and vim.fn.executable(opener) == 1 then
        for _, f in ipairs(files) do vim.system({ opener, f }, { detach = true }) end
      else
        vim.notify("Exported " .. #files .. " figure(s) (no display to open them):\n"
          .. table.concat(files, "\n"), vim.log.levels.INFO)
      end
    end,
  })
end

-- ── Project path ─────────────────────────────────────────────────────────────

--- The MATLAB command that sets up this project's path, or nil.
---
--- Explicit wins: vim.g.matlab_setup in the project's .nvim.lua (a MATLAB
--- command string; false disables the detection below). Otherwise, the two
--- conventions MATLAB itself follows:
---   • a MATLAB project (*.prj) at the root → openProject, which applies the
---     project's path, runs its startup files, and is what the desktop does
---   • a startup.m at the root → run it, as MATLAB would if started there
--- @param root string
--- @return string|nil command, string|nil description
function M.setup_command(root)
  local g = vim.g.matlab_setup
  if g == false then return nil end
  if type(g) == "string" and g ~= "" then return g, "g:matlab_setup" end

  local prj = vim.fn.glob(root .. "/*.prj", false, true)[1]
  if prj then return "openProject(" .. M.quote(prj) .. ")", vim.fs.basename(prj) end
  if vim.uv.fs_stat(root .. "/startup.m") then
    return "run(" .. M.quote(root .. "/startup.m") .. ")", "startup.m"
  end
  return nil
end

--- (Re-)apply the project's path setup in the background MATLAB.
function M.setup_project(c, on_done)
  c = c or client()
  if not c then return end
  local root = c.config.root_dir or require("config.project").root()
  local cmd, what = M.setup_command(root)
  local function done()
    state.setup_done[c.id] = true
    if on_done then on_done() end
  end
  if not cmd then return done() end

  vim.notify("MATLAB: setting up project path (" .. what .. ")", vim.log.levels.INFO)
  state.next_id = state.next_id + 1
  state.pending[state.next_id] = done
  -- A user eval, so a setup script that prints or errors is visible
  c:notify("evalRequest", { requestId = state.next_id, command = cmd, isUserEval = true })
end

-- ── Server → client notifications ────────────────────────────────────────────

local function flush_waiting(c)
  local queued = state.waiting
  state.waiting = {}
  for _, fn in ipairs(queued) do fn(c) end
end

M.handlers = {
  mvmStateChange = function(_, params, ctx)
    local c = vim.lsp.get_client_by_id(ctx.client_id)
    state.connected = params.state == "connected"
    if not state.connected then
      if c then state.setup_done[c.id] = nil end
      return
    end
    M.setup_project(c, function() flush_waiting(c) end)
  end,

  mvmPromptChange = function(_, params)
    state.prompt = params.state
  end,

  text = function(_, params)
    local text = clean(params.text or "")
    if state.bridge then
      state.bridge.output(text, params.stream == 1 and "stderr" or "stdout")
    else
      append(text)
    end
  end,

  -- input()/keyboard prompts. The reply is sent the way a typed answer would
  -- be: as the next evaluation. Cancelling interrupts the script instead of
  -- leaving MATLAB blocked on a prompt nobody can see.
  mvmInputPrompt = function(_, params)
    local prompt = type(params) == "table" and params[1] or tostring(params)
    vim.schedule(function()
      vim.ui.input({ prompt = "MATLAB " .. prompt }, function(reply)
        if reply == nil then return M.interrupt() end
        append(prompt .. reply .. "\n")
        local c = client()
        state.next_id = state.next_id + 1
        if c then c:notify("evalRequest", { requestId = state.next_id, command = reply, isUserEval = true }) end
      end)
    end)
  end,

  evalResponse = function(_, params)
    local cb = state.pending[params.requestId]
    state.pending[params.requestId] = nil
    if cb then cb() end
  end,

  DebugAdaptorResponse = function(_, params)
    if state.bridge then state.bridge.from_adapter(params.debugResponse) end
  end,

  DebugAdaptorEvent = function(_, params)
    if state.bridge then state.bridge.from_adapter(params.debugEvent) end
  end,
}

-- ── Shutdown ─────────────────────────────────────────────────────────────────
--
-- Left to itself, matlab_ls stops its MATLAB with SIGTERM when Neovim exits.
-- MATLAB counts that as a crash once graphics are up: any figure ever opened
-- means the crash reporter pops up on quit, every time. Asking MATLAB to exit
-- first lets it close its figures and shut down normally; the server then
-- finds nothing left to kill. Bounded, so a MATLAB stuck in a long computation
-- still cannot hold Neovim's exit hostage for more than a few seconds.
function M.shutdown(timeout_ms)
  local c = client()
  if not (c and state.connected) then return end
  -- The server starts a fresh MATLAB on demand whenever it finds itself
  -- without one — which, a moment after `exit`, it would, leaving a new MATLAB
  -- orphaned by Neovim's exit. Switching to "never" first stops that. The
  -- server applies settings asynchronously (it asks back for them), hence the
  -- short wait before the exit.
  local settings = vim.deepcopy(c.settings or {})
  settings.MATLAB = settings.MATLAB or {}
  settings.MATLAB.matlabConnectionTiming = "never"
  c.settings = settings
  c:notify("workspace/didChangeConfiguration", { settings = settings })
  vim.wait(300)

  if state.prompt == "BUSY" or state.prompt == "DEBUG" or state.prompt == "INPUT" then
    c:notify("interruptRequest", {})
  end
  -- `exit` called directly inside the evaluation never completes: MATLAB
  -- drops the connection but stays running. From a timer it runs once the
  -- evaluation has returned — the same way the server's own initmatlabls.m
  -- shuts MATLAB down.
  c:notify("evalRequest", {
    requestId = "exit",
    command = "if system_dependent('IsDebugMode')==1, dbquit all; end; close all force; "
      .. "start(timer('StartDelay', 0.1, 'TimerFcn', @(~, ~) exit))",
    isUserEval = false,
  })
  vim.wait(timeout_ms or 5000, function() return not state.connected end, 50)
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("matlab_session_shutdown", { clear = true }),
  callback = function() M.shutdown() end,
})

-- ── Hooks for the debug bridge ───────────────────────────────────────────────

M.client = client
M.when_ready = when_ready

function M.set_bridge(bridge)
  state.bridge = bridge
end

return M
