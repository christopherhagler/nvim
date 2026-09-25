require("config.indent").apply()

-- Indentation: MATLAB's editor default is 4 spaces, which is already the
-- global default. commentstring (% %s) comes from the runtime ftplugin.

-- Cell/section markers (%%) are how MATLAB scripts are structured; ]] / [[
-- walk them the way the MATLAB editor's "next section" does. Buffer-local,
-- so the treesitter class motions on those keys are untouched elsewhere.
local function section(flags)
  return function()
    if vim.fn.search([[^\s*%%\(\s\|$\)]], flags .. "W") == 0 then
      vim.notify("No more sections", vim.log.levels.INFO)
    end
  end
end
vim.keymap.set({ "n", "x", "o" }, "]]", section(""), { buffer = true, desc = "Next %% section" })
vim.keymap.set({ "n", "x", "o" }, "[[", section("b"), { buffer = true, desc = "Prev %% section" })

-- Running code in the background MATLAB that matlab_ls keeps alive
-- (lua/config/matlab_session.lua): no start-up cost, the workspace persists
-- between runs, and the project's path is already set up. Without a MATLAB
-- install, <leader>br falls back to the one-shot runner (Octave).
local session = require("config.matlab_session")
local map = function(mode, lhs, fn, desc)
  vim.keymap.set(mode, lhs, fn, { buffer = true, desc = "MATLAB: " .. desc })
end

map("n", "<leader>br", function()
  if require("config.matlab").install_path() then
    session.run_file()
  else
    require("config.build").run()
  end
end, "Run file")
map("n", "<leader>mr", function() session.run_file() end, "Run file")
map("n", "<leader>ms", session.run_section, "Run section")
map("x", "<leader>ms", session.run_selection, "Run selection")
map("n", "<leader>ml", function() session.eval(vim.api.nvim_get_current_line()) end, "Run line")
map("n", "<leader>mc", function()
  vim.ui.input({ prompt = ">> " }, function(cmd)
    if cmd and cmd ~= "" then session.eval(cmd) end
  end)
end, "Command")
map("n", "<leader>mh", function() session.eval("help " .. vim.fn.expand("<cword>")) end, "Help for word")
map("n", "<leader>mk", session.interrupt, "Interrupt (Ctrl-C)")
map("n", "<leader>mo", session.toggle_output, "Toggle output")
map("n", "<leader>mp", function() session.setup_project() end, "Re-run project path setup")
map("n", "<leader>mw", function() session.eval("whos") end, "Workspace variables")
-- Figures open as normal windows wherever there is a display; <leader>mf is for
-- when there is not (plain SSH to a Rocky/RHEL box)
map("n", "<leader>mf", session.export_figures, "Export figures to PNG and open")
map("n", "<leader>mx", function() session.eval("close all") end, "Close all figures")
