vim.cmd [[
if empty(glob(stdpath('data') . '/site/autoload/plug.vim'))
  silent !curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin(stdpath('data') . '/plugged')

" Core
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-fugitive'

" File tree
Plug 'preservim/nerdtree'

" Statusline
Plug 'nvim-lualine/lualine.nvim'

Plug 'puremourning/vimspector'
Plug 'nvim-treesitter/nvim-treesitter'

" Fuzzy finder
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'

" Code navigation/UI
Plug 'preservim/tagbar'
Plug 'ryanoasis/vim-devicons'
Plug 'folke/which-key.nvim'

" Linters / diagnostics
Plug 'ludovicchabant/vim-gutentags'

" Python
Plug 'psf/black'
Plug 'nvie/vim-flake8'

" Angular / TypeScript
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" Templates
Plug 'lepture/vim-jinja'

call plug#end()
]]

-- --- REMOVED ALE CONFIGURATION ---
-- The ALE configuration block at the end of the file has been removed.
