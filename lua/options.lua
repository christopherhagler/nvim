-- General Neovim options
vim.opt.tags = "./.tags;,.tags"
vim.o.clipboard = "unnamedplus"
vim.o.number = true
vim.o.relativenumber = true
vim.o.expandtab = true
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.mouse = "a"
vim.o.termguicolors = true
vim.o.cursorline = true
vim.o.hidden = true
vim.o.encoding = "utf-8"
vim.o.signcolumn = "yes"
vim.o.updatetime = 300
vim.o.backup = false
vim.o.writebackup = false

-- Trim trailing whitespace on save
vim.cmd [[
augroup trim_whitespace
  autocmd!
  autocmd BufWritePre * :%s/\s\+$//e
augroup END
]]

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  command = "silent! call CocAction('format')",
  group = vim.api.nvim_create_augroup("CoCFormatOnSave", { clear = true }),
  desc = "Format buffer with CoC on save",
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = { '<filetype>' },
  callback = function() vim.treesitter.start() end,
})
