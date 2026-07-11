return {
  -- Treesitter (main branch): parser management, highlight, indent
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      local ts = require("nvim-treesitter")

      -- Install only missing parsers. On air-gapped systems (offline RPM) the
      -- parsers ship pre-compiled, so this is a no-op that never touches the
      -- network or the parser registry.
      local have = {}
      for _, lang in ipairs(ts.get_installed()) do have[lang] = true end
      local missing = vim.tbl_filter(
        function(lang) return not have[lang] end,
        require("config.parsers")
      )
      if #missing > 0 then ts.install(missing) end

      -- The main branch has no highlight/indent modules; start them per buffer
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
        callback = function(ev)
          if pcall(vim.treesitter.start, ev.buf) then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
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

  -- Commenting: built-in gcc / gc (Neovim 0.10+), no plugin needed

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
