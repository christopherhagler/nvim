-- A reusable prompt with session-local history. Output remains in matlab://output.
local M = {}
local buf, win
local history, index, draft = {}, 1, ""
local function recall(delta)
  if index == #history + 1 then draft = vim.api.nvim_get_current_line():sub(4) end
  index = math.max(1, math.min(#history + 1, index + delta))
  vim.api.nvim_buf_set_lines(buf, -2, -1, false, { ">> " .. (history[index] or draft) })
  vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), #vim.api.nvim_get_current_line() })
end
function M.open()
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "matlab://command")
    vim.bo[buf].buftype = "prompt"
    vim.bo[buf].bufhidden = "hide"
    vim.fn.prompt_setprompt(buf, ">> ")
    vim.fn.prompt_setcallback(buf, function(code)
      if vim.trim(code) == "" then return end
      if history[#history] ~= code then history[#history + 1] = code end
      index, draft = #history + 1, ""
      require("config.matlab_session").eval(code)
    end)
    vim.fn.prompt_setinterrupt(buf, function() require("config.matlab_session").interrupt() end)
    vim.keymap.set("i", "<Up>", function() recall(-1) end, { buffer = buf, desc = "Previous MATLAB command" })
    vim.keymap.set("i", "<Down>", function() recall(1) end, { buffer = buf, desc = "Next MATLAB command" })
    vim.keymap.set("i", "<Tab>", function()
      local prefix = vim.api.nvim_get_current_line():sub(4)
      local matches, seen = {}, {}
      for i = #history, 1, -1 do
        local code = history[i]
        if vim.startswith(code, prefix) and not seen[code] then
          matches[#matches + 1] = code
          seen[code] = true
        end
      end
      if #matches > 0 then vim.fn.complete(4, matches) end
    end, { buffer = buf, desc = "Complete MATLAB command from history" })
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close MATLAB command window" })
  end
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  else
    vim.cmd("botright 6split")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.wo.number, vim.wo.relativenumber = false, false
    vim.wo.signcolumn = "no"
  end
  vim.cmd("startinsert!")
end
return M
