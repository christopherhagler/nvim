-- Test running. Before this, running a single test meant retyping a pytest or
-- jest invocation into a terminal and reading the failure as raw text; here the
-- results attach to the source as signs, and the same keypress that runs a test
-- can run it under the debugger instead.
--
-- Keys live under <leader>T rather than <leader>t, which is already the
-- terminal toggle.
return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-neotest/nvim-nio",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      -- Adapters. Each is a separate plugin and each knows how to find, run and
      -- parse the output of one framework.
      "nvim-neotest/neotest-python",
      "nvim-neotest/neotest-jest",
      "marilari88/neotest-vitest",
      "alfaix/neotest-gtest",
    },
    keys = {
      { "<leader>Tr", function() require("neotest").run.run() end, desc = "Run nearest test" },
      { "<leader>Tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file" },
      -- The project the current file belongs to, not the directory Neovim was
      -- started in — those differ the moment you open a file by path.
      { "<leader>Ta", function() require("neotest").run.run(require("config.project").root()) end,
        desc = "Run all tests" },
      { "<leader>Tl", function() require("neotest").run.run_last() end, desc = "Run last test" },
      { "<leader>Tk", function() require("neotest").run.stop() end, desc = "Stop running test" },
      -- Same test, but stopped at breakpoints in the DAP UI (lua/plugins/dap.lua)
      { "<leader>Td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Debug nearest test" },
      { "<leader>Ts", function() require("neotest").summary.toggle() end, desc = "Toggle summary tree" },
      { "<leader>To", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Show test output" },
      { "<leader>Tp", function() require("neotest").output_panel.toggle() end, desc = "Toggle output panel" },
      { "<leader>Tw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end, desc = "Watch file" },
      { "]t", function() require("neotest").jump.next({ status = "failed" }) end, desc = "Next failed test" },
      { "[t", function() require("neotest").jump.prev({ status = "failed" }) end, desc = "Prev failed test" },
    },
    config = function()
      -- Adapters are constructed defensively: they are separate projects on
      -- their own release cadence, and a single one erroring at setup time
      -- would otherwise take the whole test runner down with it.
      local adapters = {}
      local function add(module, build)
        local ok, adapter = pcall(require, module)
        if not ok then
          vim.notify("neotest: adapter " .. module .. " failed to load", vim.log.levels.DEBUG)
          return
        end
        local built_ok, built = pcall(build or function(a) return a end, adapter)
        if built_ok then table.insert(adapters, built) end
      end

      add("neotest-python", function(a)
        return a({
          -- pytest from the project's venv, matching what pyright type-checks
          -- against (lua/config/venv.lua)
          python = function() return require("config.venv").python() or "python3" end,
          runner = "pytest",
          -- Debug a failing test with <leader>Td via the debugpy already
          -- installed for nvim-dap
          dap = { justMyCode = false },
        })
      end)

      add("neotest-jest", function(a)
        return a({ jestCommand = "npm test --", jest_test_discovery = false })
      end)

      add("neotest-vitest")

      -- gtest cannot be auto-discovered the way an interpreted language can:
      -- the tests are compiled into a binary whose path only the build system
      -- knows. Record it by marking the files in the summary tree (<leader>Ts,
      -- then `m`) and running :ConfigureGtest there — the command is
      -- buffer-local to that window, not global. Stored per project, so it
      -- survives restarts.
      add("neotest-gtest", function(a) return a.setup({}) end)

      require("neotest").setup({
        adapters = adapters,
        status = { virtual_text = true },
        output = { open_on_run = false },
        quickfix = {
          -- Failures land in the quickfix list, so ]q / [q walk them the same
          -- way they walk compiler errors (lua/config/keymaps.lua)
          enabled = true,
          open = false,
        },
        icons = { passed = "", failed = "", running = "", skipped = "" },
      })
    end,
  },
}
