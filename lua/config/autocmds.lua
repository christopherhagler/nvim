local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Trim trailing whitespace on save (skip markdown: trailing spaces are
-- meaningful hard line breaks there)
autocmd("BufWritePre", {
  group = augroup("trim_whitespace", { clear = true }),
  pattern = "*",
  callback = function()
    if vim.bo.filetype == "markdown" then return end
    local pos = vim.fn.getpos(".")
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setpos(".", pos)
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
