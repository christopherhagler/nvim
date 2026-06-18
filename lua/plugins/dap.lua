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
      { "<leader>dB", function()
          require("dap").set_breakpoint(vim.fn.input("Condition: "))
        end, desc = "Conditional breakpoint" },
      { "<leader>dr", function() require("dap").repl.open() end,   desc = "Debug REPL" },
      { "<leader>dl", function() require("dap").run_last() end,    desc = "Run last" },
      { "<leader>du", function() require("dapui").toggle() end,    desc = "Toggle debug UI" },

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
      require("dap-python").setup(vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python")

      -- ── C / C++ via codelldb ────────────────────────────────────────────────
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
          args = { "--port", "${port}" },
        },
      }

      local cpp_launch = {
        {
          name = "Launch (codelldb)",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          args = {},
        },
        {
          name = "Attach (codelldb)",
          type = "codelldb",
          request = "attach",
          pid = require("dap.utils").pick_process,
          args = {},
        },
      }
      dap.configurations.c   = cpp_launch
      dap.configurations.cpp = cpp_launch

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

      local js_launch = {
        {
          type = "pwa-node",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          cwd = "${workspaceFolder}",
        },
        {
          type = "pwa-node",
          request = "attach",
          name = "Attach to process",
          processId = require("dap.utils").pick_process,
          cwd = "${workspaceFolder}",
        },
      }
      dap.configurations.javascript = js_launch
      dap.configurations.typescript = js_launch
    end,
  },
}
