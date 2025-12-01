local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

vim.g.mapleader = " "

-- =========================
-- File explorer & tabs
-- =========================
map('n', '<leader>n', ':NERDTreeToggle<CR>', opts)
map('n', '<F8>', ':TagbarToggle<CR>', opts)

-- =========================
-- Fuzzy finder (Telescope / fzf)
-- =========================
map('n', '<leader>ff', ':Telescope find_files<CR>', opts)
map('n', '<leader>fg', ':Telescope live_grep<CR>', opts)
map('n', '<leader>fb', ':Telescope buffers<CR>', opts)
map('n', '<leader>fh', ':Telescope help_tags<CR>', opts)
map('n', '<C-p>', ':Files<CR>', opts)

-- =========================
-- Window navigation
-- =========================
map('n', '<C-h>', '<C-w>h', opts)
map('n', '<C-j>', '<C-w>j', opts)
map('n', '<C-k>', '<C-w>k', opts)
map('n', '<C-l>', '<C-w>l', opts)

-- =========================
-- Basic editing
-- =========================
map('n', '<leader>w', ':w<CR>', opts)
map('i', 'jk', '<Esc>', opts)
map('n', 'n', 'nzzzv', opts)
map('n', 'N', 'Nzzzv', opts)
map('n', '<C-d>', '<C-d>zzzv', opts)
map('n', '<C-u>', '<C-u>zzzv', opts)

-- =========================
-- CoC (Code completion / LSP)
-- =========================
-- Use <TAB> and <S-TAB> to navigate completion
vim.cmd([[
inoremap <silent><expr> <TAB> coc#pum#visible() ? coc#pum#next(1) : "\<Tab>"
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : "\<CR>"

" Jump to definition
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Show hover doc
nnoremap <silent> K :call CocActionAsync('doHover')<CR>

" Rename symbol
nmap <leader>rn <Plug>(coc-rename)
]])

-- =========================
-- Diagnostics navigation
-- =========================
map('n', '[g', '<Plug>(coc-diagnostic-prev)', opts)
map('n', ']g', '<Plug>(coc-diagnostic-next)', opts)

-- =========================
-- Quickfix / code actions
-- =========================
map('x', '<leader>a', '<Plug>(coc-codeaction-selected)', opts)
map('n', '<leader>a', '<Plug>(coc-codeaction-selected)', opts)
map('n', '<leader>ac', '<Plug>(coc-codeaction-cursor)', opts)
map('n', '<leader>as', '<Plug>(coc-codeaction-source)', opts)
map('n', '<leader>qf', '<Plug>(coc-fix-current)', opts)
map('n', '<leader>re', '<Plug>(coc-codeaction-refactor)', opts)
map('x', '<leader>r', '<Plug>(coc-codeaction-refactor-selected)', opts)
map('n', '<leader>r', '<Plug>(coc-codeaction-refactor-selected)', opts)
map('n', '<leader>cl', '<Plug>(coc-codelens-action)', opts)

-- =========================
-- Selection ranges
-- =========================
map('n', '<C-s>', '<Plug>(coc-range-select)', opts)
map('x', '<C-s>', '<Plug>(coc-range-select)', opts)

-- =========================
-- Task Runner (Overseer)
-- =========================
-- Toggle the task window
map('n', '<leader>to', ':OverseerToggle<CR>', opts)
-- Run a pre-defined task
map('n', '<leader>tr', ':OverseerRun<CR>', opts)
-- Run the last task again
map('n', '<leader>tl', ':OverseerRunLast<CR>', opts)
