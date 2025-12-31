require'nvim-treesitter'.setup {
  ensure_installed = { "c", "cpp", "python", "javascript", "typescript", "java", "bash", "lua", "vim" },
  sync_install = false,
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
}
