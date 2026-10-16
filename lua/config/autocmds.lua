local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Trim trailing whitespace on save. Skipped where trailing whitespace means
-- something: markdown hard line breaks, and the single-space context lines of
-- a diff/patch. :TrimToggle (lua/config/commands.lua) turns it off for one
-- buffer, or globally with a bang — for a shared codebase that already has
-- trailing whitespace, where trimming turns a one-line change into a
-- whole-file diff.
local NO_TRIM = { markdown = true, diff = true, gitcommit = true, gitsendemail = true }
autocmd("BufWritePre", {
  group = augroup("trim_whitespace", { clear = true }),
  pattern = "*",
  callback = function(ev)
    local bo = vim.bo[ev.buf]
    if NO_TRIM[bo.filetype] or bo.buftype ~= "" or not bo.modifiable then return end
    if vim.g.notrim or vim.b[ev.buf].notrim then return end
    local view = vim.fn.winsaveview()
    -- keeppatterns: without it the substitution becomes the last search
    -- pattern, so every save leaves trailing whitespace lit up by 'hlsearch'
    -- and hijacks the next n/N.
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- Reload buffers changed outside Neovim (e.g. by Claude Code or git)
autocmd({ "FocusGained", "BufEnter", "TermLeave" }, {
  group = augroup("checktime", { clear = true }),
  callback = function()
    if vim.o.buftype == "" then vim.cmd("checktime") end
  end,
})
autocmd("FileChangedShellPost", {
  group = augroup("file_reloaded", { clear = true }),
  callback = function()
    vim.notify("File changed on disk, buffer reloaded", vim.log.levels.INFO)
  end,
})

-- Highlight yanked text briefly
autocmd("TextYankPost", {
  group = augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- Equalize splits on terminal resize
autocmd("VimResized", {
  group = augroup("resize_splits", { clear = true }),
  -- :tabdo leaves the last tab current, so come back to where we were
  callback = function()
    local tab = vim.api.nvim_get_current_tabpage()
    vim.cmd("tabdo wincmd =")
    vim.api.nvim_set_current_tabpage(tab)
  end,
})

-- Return to last cursor position when reopening a file
-- (not for commit/rebase messages, which are a new message every time)
autocmd("BufReadPost", {
  group = augroup("last_location", { clear = true }),
  callback = function(ev)
    local ft = vim.bo[ev.buf].filetype
    if ft == "gitcommit" or ft == "gitrebase" then return end
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close certain windows with q
autocmd("FileType", {
  group = augroup("close_with_q", { clear = true }),
  pattern = { "help", "lspinfo", "man", "notify", "qf", "checkhealth" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", function()
      -- :close refuses to close the last window (E444), e.g. `nvim +help`
      if #vim.api.nvim_tabpage_list_wins(0) > 1 or vim.fn.tabpagenr("$") > 1 then
        vim.cmd("close")
      else
        vim.cmd("bdelete")
      end
    end, { buffer = ev.buf, silent = true, desc = "Close window" })
  end,
})

-- Terminal-mode keys for every terminal — toggleterm, the <leader>br run
-- split, Claude and the debug console — so leaving and moving between windows
-- works the same in all of them. <Esc><Esc> rather than <Esc>: a single <Esc>
-- still reaches the program (vi-mode shells, fzf, lazygit, htop), just after
-- 'timeoutlen'. Claude's terminal keeps <Esc><Esc> for itself (it is Claude
-- Code's own rewind key); <C-\><C-n> leaves terminal mode anywhere.
autocmd("TermOpen", {
  group = augroup("terminal_keymaps", { clear = true }),
  callback = function(ev)
    local opts = function(desc) return { buffer = ev.buf, desc = desc } end
    -- term://{cwd}//{pid}:{command} — match the command, not the cwd
    local command = vim.api.nvim_buf_get_name(ev.buf):match("^term://.-//%d+:(.*)$") or ""
    if not vim.fs.basename(vim.split(command, " ")[1] or ""):find("claude", 1, true) then
      vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", opts("Leave terminal mode"))
    end
    vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", opts("Window left"))
    vim.keymap.set("t", "<C-j>", "<C-\\><C-n><C-w>j", opts("Window down"))
    vim.keymap.set("t", "<C-k>", "<C-\\><C-n><C-w>k", opts("Window up"))
    vim.keymap.set("t", "<C-l>", "<C-\\><C-n><C-w>l", opts("Window right"))
  end,
})
