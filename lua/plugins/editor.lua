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

      -- Treesitter indentation is still marked experimental upstream and is
      -- noticeably worse than the runtime indent scripts for these languages,
      -- so keep highlighting but leave 'indentexpr' alone.
      local no_ts_indent = { python = true }

      -- Parsing a very large file blocks the UI for seconds; fall back to
      -- regex syntax instead.
      local max_filesize = 1024 * 1024 -- 1 MiB

      -- The main branch has no highlight/indent modules; start them per buffer
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
        callback = function(ev)
          local size = vim.fn.getfsize(vim.api.nvim_buf_get_name(ev.buf))
          if size > max_filesize then return end
          if pcall(vim.treesitter.start, ev.buf) and not no_ts_indent[ev.match] then
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

  -- Project-wide search and replace. Telescope finds across the project but
  -- cannot change anything; this is the write half. Results open in a normal
  -- buffer you edit in place, then <leader>rp applies them across every file.
  -- Backed by the same ripgrep the RPM already bundles (rpm/build-rpm.sh).
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    keys = {
      {
        "<leader>rr",
        function() require("grug-far").open() end,
        desc = "Replace in project",
      },
      {
        "<leader>rw",
        function() require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } }) end,
        desc = "Replace word under cursor",
      },
      {
        "<leader>rf",
        function() require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } }) end,
        desc = "Replace in current file",
      },
      {
        "<leader>rr",
        mode = "v",
        function() require("grug-far").with_visual_selection() end,
        desc = "Replace selection in project",
      },
    },
    opts = {
      -- maplocalleader is ',' — the same key as mapleader — so grug-far's
      -- '<localleader><letter>' defaults land directly on our leader namespace.
      -- The ones remapped here are those whose default is a *prefix* of an
      -- existing mapping (,r ,l ,q ,c ,f ,x) or that would shadow a complete
      -- one (,t ,w). Left alone, each would make the global key wait out
      -- 'timeoutlen' inside a grug-far buffer — the same trap the grr defaults
      -- set in lua/plugins/lsp.lua. Everything not listed keeps its default.
      keymaps = {
        replace = { n = "<leader>ra" }, -- apply all replacements
        syncLocations = { n = "<leader>rs" },
        syncLine = { n = "<leader>rl" },
        qflist = { n = "<leader>rq" },
        close = { n = "<leader>rc" },
        refresh = { n = "<leader>ru" },
        historyOpen = { n = "<leader>rh" },
        swapReplacementInterpreter = { n = "<leader>rx" },
        toggleShowCommand = { n = "<leader>rm" },
      },
    },
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
