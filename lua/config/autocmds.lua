local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Trim trailing whitespace on save (skip markdown: trailing spaces are
-- meaningful hard line breaks there)
autocmd("BufWritePre", {
  group = augroup("trim_whitespace", { clear = true }),
  pattern = "*",
  callback = function(ev)
    local bo = vim.bo[ev.buf]
    if bo.filetype == "markdown" or bo.buftype ~= "" or not bo.modifiable then return end
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
  callback = function() vim.cmd("tabdo wincmd =") end,
})

-- Return to last cursor position when reopening a file
autocmd("BufReadPost", {
  group = augroup("last_location", { clear = true }),
  callback = function()
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
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
  end,
})
