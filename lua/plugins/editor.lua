return {
  -- Treesitter: syntax highlighting, indent, folding
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "c", "cpp", "python",
          "javascript", "typescript", "tsx",
          "html", "css", "json", "yaml",
          "lua", "vim", "vimdoc", "bash",
          "markdown", "markdown_inline",
          "asm",
        },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "<C-space>",
            node_incremental = "<C-space>",
            node_decremental = "<bs>",
          },
        },
      })
    end,
  },

  -- Shows current function/class context at top of window
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = { "BufReadPre", "BufNewFile" },
    opts = { max_lines = 3 },
  },

  -- Auto-close brackets and quotes
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = { check_ts = true },
  },

  -- gcc / gc for commenting
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },

  -- cs"' / ds" / ysiw" style surround
  {
    "kylechui/nvim-surround",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },

  -- Highlight all occurrences of the word under cursor
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("illuminate").configure({
        providers = { "lsp", "treesitter", "regex" },
        delay = 200,
        filetypes_denylist = { "NvimTree", "aerial", "TelescopePrompt", "alpha" },
      })
    end,
  },
}
