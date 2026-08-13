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

  -- Syntax-aware text objects: daf deletes a function, cia changes an argument,
  -- ]f jumps to the next one. These work identically in C, C++, Python, Lua and
  -- TS because they are defined against the parse tree rather than per-language
  -- regexes — the single biggest editing win available from treesitter.
  --
  -- Pinned to the main branch to match nvim-treesitter above: the master branch
  -- configures itself through nvim-treesitter.configs, which main removed, so
  -- mixing the two silently installs no mappings at all.
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = {
          -- Start the textobject from just before the cursor if there is none
          -- under it, so `cif` works from the blank line above a function
          lookahead = true,
        },
        move = { set_jumps = true }, -- <C-o> returns from a ]f jump
      })

      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")
      local swap = require("nvim-treesitter-textobjects.swap")

      -- a = "around" (includes the signature/braces), i = "inside" (the body)
      local objects = {
        f = "function",
        c = "class",
        a = "parameter",
        i = "conditional",
        l = "loop",
        m = "call",
      }
      for key, obj in pairs(objects) do
        for _, part in ipairs({ "outer", "inner" }) do
          local lhs = (part == "outer" and "a" or "i") .. key
          vim.keymap.set({ "x", "o" }, lhs, function()
            select.select_textobject("@" .. obj .. "." .. part, "textobjects")
          end, { desc = ("%s %s"):format(part == "outer" and "Around" or "Inside", obj) })
        end
      end

      -- Movement. ]c / [c are left alone: gitsigns owns them for hunks.
      local moves = {
        ["]f"] = { move.goto_next_start, "@function.outer", "Next function" },
        ["[f"] = { move.goto_previous_start, "@function.outer", "Prev function" },
        ["]F"] = { move.goto_next_end, "@function.outer", "Next function end" },
        ["[F"] = { move.goto_previous_end, "@function.outer", "Prev function end" },
        ["]]"] = { move.goto_next_start, "@class.outer", "Next class" },
        ["[["] = { move.goto_previous_start, "@class.outer", "Prev class" },
      }
      for lhs, spec in pairs(moves) do
        vim.keymap.set({ "n", "x", "o" }, lhs, function()
          spec[1](spec[2], "textobjects")
        end, { desc = spec[3] })
      end

      -- Reorder arguments and functions without a visual selection
      vim.keymap.set("n", "<leader>sa", function() swap.swap_next("@parameter.inner") end,
        { desc = "Swap parameter with next" })
      vim.keymap.set("n", "<leader>sA", function() swap.swap_previous("@parameter.inner") end,
        { desc = "Swap parameter with prev" })
      vim.keymap.set("n", "<leader>sf", function() swap.swap_next("@function.outer") end,
        { desc = "Swap function with next" })
      vim.keymap.set("n", "<leader>sF", function() swap.swap_previous("@function.outer") end,
        { desc = "Swap function with prev" })
    end,
  },

  -- % jumps between more than brackets: #if/#else/#endif in C, if/end in Lua,
  -- do/done in shell, opening/closing tags in HTML.
  {
    "andymass/vim-matchup",
    event = { "BufReadPre", "BufNewFile" },
    init = function()
      -- The offscreen popup would duplicate nvim-treesitter-context, which is
      -- already showing the enclosing function at the top of the window.
      vim.g.matchup_matchparen_offscreen = {}
    end,
  },

  -- Generate a documentation comment for the symbol under the cursor, in each
  -- language's own convention: doxygen for C/C++, google-style for Python,
  -- JSDoc for JS/TS, LDoc for Lua.
  {
    "danymat/neogen",
    cmd = "Neogen",
    keys = {
      { "<leader>ld", function() require("neogen").generate() end, desc = "Generate doc comment" },
    },
    opts = {
      snippet_engine = "nvim", -- built-in vim.snippet, no extra dependency
      languages = {
        c = { template = { annotation_convention = "doxygen" } },
        cpp = { template = { annotation_convention = "doxygen" } },
        python = { template = { annotation_convention = "google_docstrings" } },
        lua = { template = { annotation_convention = "ldoc" } },
      },
    },
  },

  -- Browse the undo tree. 'undofile' is on (lua/config/options.lua), so this
  -- reaches edits from previous sessions, which u/<C-r> alone cannot.
  {
    "mbbill/undotree",
    cmd = "UndotreeToggle",
    keys = { { "<leader>u", "<cmd>UndotreeToggle<cr>", desc = "Toggle undo tree" } },
    init = function()
      vim.g.undotree_WindowLayout = 2      -- tree left, diff below it
      vim.g.undotree_SetFocusWhenToggle = 1
    end,
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
