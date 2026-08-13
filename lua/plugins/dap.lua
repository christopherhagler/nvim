return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      -- UI
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
      -- Inline variable values during debug
      "theHamsta/nvim-dap-virtual-text",
      -- Python adapter
      "mfussenegger/nvim-dap-python",
    },
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
      { "<leader>dB", function()
          require("dap").set_breakpoint(vim.fn.input("Condition: "))
        end, desc = "Conditional breakpoint" },
      -- Stop where the cursor is without leaving a breakpoint behind — the
      -- "why is it not reaching this line" question, answered in one key.
      { "<leader>dc", function() require("dap").run_to_cursor() end, desc = "Run to cursor" },
      -- Break on a raised exception / a signal / a failed assert, chosen from
      -- the list the adapter itself reports (differs per language).
      { "<leader>de", function() require("dap").set_exception_breakpoints() end, desc = "Exception breakpoints" },
      { "<leader>dr", function() require("dap").repl.open() end,   desc = "Debug REPL" },
      { "<leader>dl", function() require("dap").run_last() end,    desc = "Run last" },
      { "<leader>dt", function() require("dap").terminate() end,   desc = "Terminate session" },
      { "<leader>du", function() require("dapui").toggle() end,    desc = "Toggle debug UI" },
      -- Evaluate the expression under the cursor, or the visual selection
      { "<leader>dv", function() require("dapui").eval(nil, { enter = true }) end,
        mode = { "n", "v" }, desc = "Evaluate expression" },
      { "<leader>dC", function() require("dap").clear_breakpoints() end, desc = "Clear all breakpoints" },

      -- VSCode-style function-key debugging
      { "<F5>",    function() require("dap").continue() end,          desc = "Debug: Continue / Start" },
      { "<S-F5>",  function() require("dap").terminate() end,         desc = "Debug: Terminate" },
      { "<F9>",    function() require("dap").toggle_breakpoint() end, desc = "Debug: Toggle breakpoint" },
      { "<F10>",   function() require("dap").step_over() end,         desc = "Debug: Step over" },
      { "<F11>",   function() require("dap").step_into() end,         desc = "Debug: Step into" },
      { "<S-F11>", function() require("dap").step_out() end,          desc = "Debug: Step out" },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- Breakpoint signs. The default is a plain "B" in the normal foreground
      -- colour, which is genuinely hard to spot in a sign column already shared
      -- with gitsigns and diagnostics.
      local signs = {
        DapBreakpoint          = { "", "DiagnosticError" },
        DapBreakpointCondition = { "", "DiagnosticWarn" },
        DapLogPoint            = { "", "DiagnosticInfo" },
        DapBreakpointRejected  = { "", "DiagnosticHint" },
      }
      for name, sign in pairs(signs) do
        vim.fn.sign_define(name, { text = sign[1], texthl = sign[2], numhl = sign[2] })
      end
      -- The stopped line also gets a full-width highlight: when execution stops
      -- somewhere unexpected, the sign alone is easy to miss.
      vim.fn.sign_define("DapStopped",
        { text = "", texthl = "DiagnosticWarn", linehl = "Visual", numhl = "DiagnosticWarn" })

      -- DAP UI
      dapui.setup({
        icons = { expanded = "", collapsed = "", current_frame = "" },
        layouts = {
          {
            elements = {
              { id = "scopes",      size = 0.35 },
              { id = "breakpoints", size = 0.20 },
              { id = "stacks",      size = 0.25 },
              { id = "watches",     size = 0.20 },
            },
            size = 40,
            position = "left",
          },
          {
            elements = { "repl", "console" },
            size = 0.25,
            position = "bottom",
          },
        },
      })

      -- Auto open/close UI with debug session
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

      -- Inline variable values
      require("nvim-dap-virtual-text").setup({ commented = true })

      -- ── Python ──────────────────────────────────────────────────────────────
      -- Uses the debugpy installed by mason-tool-installer
      local dap_python = require("dap-python")
      dap_python.setup(vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python")

      -- The line above says which python *runs debugpy*; this says which python
      -- runs the code being debugged. They are not the same: debugpy lives in
      -- Mason's own venv, while the program needs the project's, or every
      -- third-party import fails under the debugger only.
      dap_python.resolve_python = function()
        return require("config.venv").python() or "python3"
      end

      -- ── C / C++ ─────────────────────────────────────────────────────────────
      -- Two adapters, because the two machines need different ones:
      --   • codelldb (LLDB) — local debugging on this macOS arm64 box; gdb has no
      --     working native arm64-Darwin build, so LLDB is the only local option.
      --   • cppdbg (cpptools) — drives gdb over GDB/MI on Linux/RHEL, works with any
      --     gdb version (even ones predating gdb's native DAP) and attaches to a
      --     remote gdbserver. Config schema matches VSCode launch.json (loaded below).
      -- Registering both is conflict-free; <F5> just lists every config in a picker.
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
          args = { "--port", "${port}" },
        },
      }

      dap.adapters.cppdbg = {
        id = "cppdbg",
        type = "executable",
        command = vim.fn.stdpath("data")
          .. "/mason/packages/cpptools/extension/debugAdapters/bin/OpenDebugAD7",
      }

      -- Resolve which gdb binary to use, so each project can pin its own version:
      --   • vim.g.gdb_path  — set in a project-local .nvim.lua or :let g:gdb_path = "…"
      --   • $GDB            — environment variable
      --   • "gdb"           — from $PATH (fallback)
      local function gdb_path()
        return vim.g.gdb_path or vim.env.GDB or "gdb"
      end

      -- Choosing what to debug used to be a bare vim.fn.input() with no
      -- completion history: the full path to the binary, retyped on every
      -- single launch. Instead, look where build systems actually put things
      -- and offer the results newest-first, since the binary you just rebuilt
      -- is nearly always the one you want.
      local BUILD_DIRS = { "build", "bin", "out", "cmake-build-debug", "cmake-build-release", "target/debug" }
      -- Extensions that are never a debuggable program, but do litter a build
      -- directory in the thousands.
      local NOT_A_PROGRAM = {
        o = true, a = true, so = true, dylib = true, lo = true, la = true, d = true,
        cmake = true, txt = true, json = true, ninja = true, make = true, log = true,
        h = true, hpp = true, c = true, cpp = true, sh = true, py = true, ["1"] = true,
      }

      local last_choice = {}

      -- Directories that contain executables but never *the* executable: git
      -- hooks are the classic false positive, node_modules/.bin the noisiest.
      local NEVER_SCAN = { "/.git/", "/node_modules/", "/.venv/", "/CMakeFiles/", "/.cache/" }

      local function find_executables(root)
        local found, seen = {}, {}

        local function scan(dir)
          local path = root .. "/" .. dir
          if not vim.uv.fs_stat(path) then return end
          -- depth 3 reaches CMake's per-target subdirectories without
          -- descending into vendored dependency trees
          for name, type in vim.fs.dir(path, { depth = 3 }) do
            local full = vim.fs.normalize(path .. "/" .. name)
            local ext = name:match("%.([^./]+)$")
            local skip = seen[full] or (ext and NOT_A_PROGRAM[ext:lower()])
            for _, pattern in ipairs(NEVER_SCAN) do
              skip = skip or full:find(pattern, 1, true) ~= nil
            end
            if type == "file" and not skip and vim.fn.executable(full) == 1 then
              seen[full] = true
              local stat = vim.uv.fs_stat(full)
              table.insert(found, { path = full, mtime = stat and stat.mtime.sec or 0 })
            end
            if #found > 200 then return end
          end
        end

        for _, dir in ipairs(BUILD_DIRS) do
          scan(dir)
          if #found > 200 then break end
        end
        -- The project root itself is the last resort, and only when the
        -- conventional build directories turned up nothing: scanning a whole
        -- source tree is both slow and mostly noise.
        if #found == 0 then scan(".") end

        table.sort(found, function(a, b) return a.mtime > b.mtime end)
        return vim.tbl_map(function(e) return e.path end, found)
      end

      local MANUAL = "→ Enter a path manually…"

      -- nvim-dap calls configuration functions inside a coroutine and will
      -- resume one that is handed back, which is what makes an async picker
      -- (vim.ui.select) usable where a blocking prompt used to be.
      local function pick_executable()
        local root = require("config.project").root()
        local candidates = find_executables(root)

        -- Float the previous choice for this project to the top
        local previous = last_choice[root]
        if previous then
          candidates = vim.tbl_filter(function(p) return p ~= previous end, candidates)
          table.insert(candidates, 1, previous)
        end
        table.insert(candidates, MANUAL)

        return coroutine.create(function(dap_co)
          local function finish(path)
            if path and path ~= "" then last_choice[root] = path end
            coroutine.resume(dap_co, path)
          end

          vim.ui.select(candidates, {
            prompt = "Debug which executable?",
            format_item = function(item)
              if item == MANUAL then return item end
              -- Shown relative to the project root; a build/ path is otherwise
              -- mostly a repeat of the same long absolute prefix.
              return (vim.fs.relpath and vim.fs.relpath(root, item)) or item
            end,
          }, function(choice)
            if choice == nil then
              finish(nil) -- cancelled: dap aborts the launch
            elseif choice == MANUAL then
              vim.ui.input({ prompt = "Executable: ", default = root .. "/", completion = "file" }, finish)
            else
              finish(choice)
            end
          end)
        end)
      end

      -- Program arguments, asked for only by the "with arguments" configs so
      -- the common case stays a single keypress.
      local function prompt_args()
        return coroutine.create(function(dap_co)
          vim.ui.input({ prompt = "Program arguments: " }, function(input)
            coroutine.resume(dap_co, vim.split(input or "", " +", { trimempty = true }))
          end)
        end)
      end

      local pretty = {
        { text = "-enable-pretty-printing", description = "enable pretty printing", ignoreFailures = false },
      }

      -- LLDB configs (local macOS debugging)
      local lldb_cfgs = {
        {
          name = "Launch (codelldb)",
          type = "codelldb",
          request = "launch",
          program = pick_executable,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          args = {},
          -- Without a real terminal the debuggee's stdout is swallowed and
          -- anything reading stdin hangs with no indication why.
          terminal = "integrated",
        },
        {
          name = "Launch with arguments (codelldb)",
          type = "codelldb",
          request = "launch",
          program = pick_executable,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          args = prompt_args,
          terminal = "integrated",
        },
        {
          name = "Attach (codelldb)",
          type = "codelldb",
          request = "attach",
          pid = require("dap.utils").pick_process,
          args = {},
        },
      }

      -- gdb configs (Linux/RHEL local + remote gdbserver)
      local gdb_cfgs = {
        {
          name = "Launch (gdb)",
          type = "cppdbg",
          request = "launch",
          program = pick_executable,
          cwd = "${workspaceFolder}",
          stopAtEntry = false,
          MIMode = "gdb",
          miDebuggerPath = gdb_path,
          setupCommands = pretty,
          externalConsole = false,
        },
        {
          name = "Launch with arguments (gdb)",
          type = "cppdbg",
          request = "launch",
          program = pick_executable,
          args = prompt_args,
          cwd = "${workspaceFolder}",
          stopAtEntry = false,
          MIMode = "gdb",
          miDebuggerPath = gdb_path,
          setupCommands = pretty,
          externalConsole = false,
        },
        {
          name = "Attach (gdb)",
          type = "cppdbg",
          request = "attach",
          program = pick_executable,
          processId = require("dap.utils").pick_process,
          MIMode = "gdb",
          miDebuggerPath = gdb_path,
          setupCommands = pretty,
        },
        {
          name = "Remote (gdbserver)",
          type = "cppdbg",
          request = "launch",
          program = pick_executable,
          cwd = "${workspaceFolder}",
          MIMode = "gdb",
          miDebuggerPath = gdb_path,
          miDebuggerServerAddress = function()
            return vim.fn.input("gdbserver address: ", "localhost:1234")
          end,
          setupCommands = pretty,
        },
      }

      -- List the platform-appropriate adapter first so the default pick is usable:
      -- LLDB on this Mac, gdb on Linux/RHEL. (All configs stay available on both.)
      local cpp_launch
      if vim.fn.has("mac") == 1 then
        cpp_launch = vim.list_extend(vim.deepcopy(lldb_cfgs), gdb_cfgs)
      else
        cpp_launch = vim.list_extend(vim.deepcopy(gdb_cfgs), lldb_cfgs)
      end
      dap.configurations.c   = cpp_launch
      dap.configurations.cpp = cpp_launch

      -- Per-project overrides (miDebuggerPath, args, gdbserver address, …) come
      -- from .vscode/launch.json, which nvim-dap reads automatically on demand
      -- (:help dap-providers-configs).

      -- ── JavaScript / TypeScript via js-debug-adapter ────────────────────────
      dap.adapters["pwa-node"] = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
          command = "node",
          args = {
            vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
            "${port}",
          },
        },
      }

      -- The same js-debug server also drives Chrome, which is the half of web
      -- work that node-only debugging cannot reach: component state, event
      -- handlers, anything that only exists in the browser.
      dap.adapters["pwa-chrome"] = dap.adapters["pwa-node"]

      local js_launch = {
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          cwd = "${workspaceFolder}",
          sourceMaps = true,
          -- Stepping through node's own internals is never the goal
          skipFiles = { "<node_internals>/**" },
        },
        {
          type = "pwa-node",
          request = "attach",
          name = "Attach to process",
          processId = require("dap.utils").pick_process,
          cwd = "${workspaceFolder}",
          sourceMaps = true,
          skipFiles = { "<node_internals>/**" },
        },
        {
          type = "pwa-chrome",
          request = "launch",
          name = "Launch Chrome against dev server",
          url = function()
            return coroutine.create(function(dap_co)
              vim.ui.input({ prompt = "Dev server URL: ", default = "http://localhost:3000" }, function(url)
                coroutine.resume(dap_co, url)
              end)
            end)
          end,
          webRoot = "${workspaceFolder}",
          sourceMaps = true,
        },
      }

      -- React files are their own filetypes in Neovim and get no configs unless
      -- listed, which is why breakpoints in a .tsx used to do nothing.
      for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
        dap.configurations[ft] = js_launch
      end

      -- ── Bash via bash-debug-adapter (bashdb) ────────────────────────────────
      -- bashdb needs bash >= 4 to run the debugged script; macOS /bin/bash is
      -- stuck at 3.2, so prefer Homebrew's bash when present.
      local function debug_bash()
        for _, p in ipairs({ "/opt/homebrew/bin/bash", "/usr/local/bin/bash" }) do
          if vim.fn.executable(p) == 1 then return p end
        end
        return "bash"
      end

      local bashdb_dir = vim.fn.stdpath("data")
        .. "/mason/packages/bash-debug-adapter/extension/bashdb_dir"

      dap.adapters.bashdb = {
        type = "executable",
        command = vim.fn.stdpath("data") .. "/mason/bin/bash-debug-adapter",
        name = "bashdb",
      }

      local function bash_config(name, args)
        return {
          type = "bashdb",
          request = "launch",
          name = name,
          program = "${file}",
          file = "${file}",
          cwd = "${workspaceFolder}",
          pathBashdb = bashdb_dir .. "/bashdb",
          pathBashdbLib = bashdb_dir,
          pathBash = debug_bash(),
          pathCat = "cat",
          pathMkfifo = "mkfifo",
          pathPkill = "pkill",
          env = {},
          args = args,
          showDebugOutput = true,
        }
      end

      dap.configurations.sh = {
        bash_config("Launch current script", {}),
        bash_config("Launch with arguments", function()
          return vim.split(vim.fn.input("Script arguments: "), " +", { trimempty = true })
        end),
      }
      dap.configurations.bash = dap.configurations.sh
    end,
  },
}
