local map = vim.keymap.set

-- Save
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })

-- Exit insert mode
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Centered search navigation
map("n", "n", "nzzzv", { desc = "Next search result" })
map("n", "N", "Nzzzv", { desc = "Prev search result" })

-- Centered scrolling
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up" })

-- Better indenting in visual mode (stay in visual)
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Buffer navigation
map("n", "]b", "<cmd>bnext<cr>",     { desc = "Next buffer" })
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Prev buffer" })

-- Quickfix / location list navigation. This is the list every compiler error,
-- grep hit and LSP reference lands in, so it needs motions as cheap as ]b.
-- Both wrap: :cnext at the end of the list raises E553 rather than cycling,
-- which is never what you want mid-build.
local function list_jump(step, wrap)
  if not pcall(vim.cmd, step) then pcall(vim.cmd, wrap) end
  pcall(vim.cmd, "normal! zz")
end

map("n", "]q", function() list_jump("cnext", "cfirst") end,     { desc = "Next quickfix item" })
map("n", "[q", function() list_jump("cprevious", "clast") end,  { desc = "Prev quickfix item" })
map("n", "]l", function() list_jump("lnext", "lfirst") end,     { desc = "Next loclist item" })
map("n", "[l", function() list_jump("lprevious", "llast") end,  { desc = "Prev loclist item" })

-- Toggle the quickfix window itself (Trouble's <leader>xq is the prettier
-- view; this is the raw list, which is what :make and :grep populate)
map("n", "<leader>xc", function()
  local open = vim.iter(vim.fn.getwininfo()):any(function(w) return w.quickfix == 1 and w.loclist == 0 end)
  vim.cmd(open and "cclose" or "copen")
end, { desc = "Toggle quickfix window" })

-- Show diagnostics for the current line
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Line diagnostics" })

-- Build / run. Detection and the quickfix plumbing live in lua/config/build.lua;
-- a project overrides either command from its .nvim.lua (see 'exrc').
map("n", "<leader>bb", function() require("config.build").build() end, { desc = "Build project" })
map("n", "<leader>br", function() require("config.build").run() end,   { desc = "Run current file" })
map("n", "<leader>bk", function() require("config.build").stop() end,  { desc = "Stop build" })
map("n", "<leader>bc", function()
  vim.ui.input({ prompt = "Build command: ", default = select(1, require("config.build").build_cmd()) },
    function(cmd)
      if cmd and cmd ~= "" then require("config.build").build(cmd) end
    end)
end, { desc = "Build with a custom command" })

-- Format (global, not LSP-scoped: conform handles filetypes such as yaml and
-- scss that have no language server attached). In visual mode conform detects
-- the selection and formats only that range.
map({ "n", "v" }, "<leader>lf", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer/selection" })
