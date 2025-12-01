set nocompatible
filetype plugin indent on
syntax on

" Load global Lua configs
lua require('options')
lua require('plugins')
lua require('mappings')
lua require('plugin_config/treesitter')
lua require('plugin_config/lualine')
lua require('plugin_config/overseer')

let g:gutentags_ctags_tagfile = '.tags'

" Initialize which-key
lua << EOF
  require("which-key").setup {}
EOF
