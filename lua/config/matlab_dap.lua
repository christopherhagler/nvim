-- nvim-dap adapter for MATLAB, bridged onto matlab_ls.
--
-- MathWorks ship a real Debug Adapter Protocol implementation, but inside the
-- language server rather than as a program: DAP requests go in as LSP
-- notifications (DebugAdaptorRequest) and responses and events come back the
-- same way. nvim-dap can only talk to a process, a socket or a pipe, so this
-- opens a loopback socket inside Neovim for nvim-dap to connect to and relays
-- between the two. Nothing is spawned; the MATLAB being debugged is the one the
-- language server already runs (lua/config/matlab_session.lua), with the
-- project path already set up.
--
-- The adapter treats `launch` as a no-op — in VS Code, code is started from
-- the MATLAB terminal and the debugger merely watches. So the relay starts the
-- program itself, after configurationDone (by which point every breakpoint is
-- set), and ends the session when the evaluation returns.

local M = {}

local function encode(msg)
  local body = vim.json.encode(msg)
  return ("Content-Length: %d\r\n\r\n%s"):format(#body, body)
end

--- Adapter factory for dap.adapters.matlab.
function M.adapter(callback, config)
  local session = require("config.matlab_session")

  session.when_ready(function(c)
    local server = assert(vim.uv.new_tcp())
    server:bind("127.0.0.1", 0)

    server:listen(1, function(listen_err)
      if listen_err then return end
      local sock = assert(vim.uv.new_tcp())
      server:accept(sock)
      server:close() -- one debug session per adapter instance

      local alive, ended = true, false
      local start_after = nil -- seq of configurationDone
      local launch_args = config
      local buffer = ""

      local function send(msg)
        if alive and not sock:is_closing() then sock:write(encode(msg)) end
      end
      local function event(name, body)
        send({ seq = 0, type = "event", event = name, body = body })
      end

      local function finish()
        if not ended then
          ended = true
          event("exited", { exitCode = 0 })
          event("terminated", {})
        end
      end

      local function close()
        if not alive then return end
        alive = false
        session.set_bridge(nil)
        -- MATLAB keeps breakpoints after the debugger goes away; left in place,
        -- the next plain run would stop at one with nothing attached to show it.
        session.eval("dbclear all", { silent = true })
        if not sock:is_closing() then sock:close() end
      end

      -- Start the program: a command from the config, or run() on the file
      local function start()
        local code = launch_args.command
        if not code or code == "" then
          code = "run(" .. session.quote(launch_args.program) .. ")"
        end
        event("output", { category = "console", output = ">> " .. code .. "\n" })
        session.eval(code, { echo = false, on_done = finish })
      end

      local function from_client(msg)
        if msg.type ~= "request" then return end
        if msg.command == "launch" then
          launch_args = vim.tbl_extend("force", launch_args, msg.arguments or {})
        elseif msg.command == "configurationDone" then
          start_after = msg.seq
        end
        c:notify("DebugAdaptorRequest", { debugRequest = msg, tag = msg.seq })
      end

      session.set_bridge({
        from_adapter = function(msg)
          if msg.type == "event" and msg.event == "terminated" then ended = true end
          send(msg)
          if msg.type == "response" then
            if msg.request_seq == start_after then
              start_after = nil
              start()
            elseif msg.command == "disconnect" then
              close()
            end
          end
        end,
        output = function(text, category)
          event("output", { category = category, output = text })
        end,
      })

      sock:read_start(function(read_err, chunk)
        if read_err or not chunk then
          vim.schedule(close)
          return
        end
        buffer = buffer .. chunk
        while true do
          local header_end = buffer:find("\r\n\r\n", 1, true)
          if not header_end then break end
          local len = tonumber(buffer:sub(1, header_end):match("Content%-Length: (%d+)"))
          if not len or #buffer < header_end + 3 + len then break end
          local body = buffer:sub(header_end + 4, header_end + 3 + len)
          buffer = buffer:sub(header_end + 4 + len)
          local ok, msg = pcall(vim.json.decode, body)
          if ok then vim.schedule(function() from_client(msg) end) end
        end
      end)
    end)

    callback({ type = "server", host = "127.0.0.1", port = server:getsockname().port })
  end)
end

-- Launch configurations: <F5> in a .m buffer offers these
M.configurations = {
  {
    type = "matlab",
    request = "launch",
    name = "Run current file (MATLAB)",
    program = "${file}",
  },
  {
    -- For functions, which need arguments: `myfunc(2, 'x')`, or any statement
    type = "matlab",
    request = "launch",
    name = "Run command (MATLAB)",
    command = function()
      return coroutine.create(function(dap_co)
        local default = vim.fn.expand("%:t:r")
        vim.ui.input({ prompt = "MATLAB command: ", default = default ~= "" and default .. "(" or "" }, function(cmd)
          coroutine.resume(dap_co, cmd or require("dap").ABORT)
        end)
      end)
    end,
  },
}

return M
