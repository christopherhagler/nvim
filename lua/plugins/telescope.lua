return {
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function() return vim.fn.executable("make") == 1 end,
      },
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
      { "<leader>fd", "<cmd>Telescope diagnostics<cr>", desc = "Diagnostics" },
      { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Document symbols" },
      { "<C-p>", "<cmd>Telescope find_files<cr>", desc = "Find files" },

      -- Symbols across the whole project, not just this buffer. On a C or C++
      -- tree this is the fastest way to reach a function whose file you don't
      -- know — it queries clangd's index rather than the filesystem.
      { "<leader>fS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", desc = "Workspace symbols" },
      -- Grep the word under the cursor / the visual selection, without typing it
      { "<leader>fw", "<cmd>Telescope grep_string<cr>", desc = "Grep word under cursor" },
      { "<leader>fw", "<cmd>Telescope grep_string<cr>", mode = "v", desc = "Grep selection" },
      -- Fuzzy find inside the current buffer (the / that tolerates typos).
      -- This is the one builtin that reaches for nvim-treesitter on every call
      -- rather than caching it at load, so it needs the shim each time.
      {
        "<leader>f/",
        function()
          require("config.tscompat").with(function()
            require("telescope.builtin").current_buffer_fuzzy_find()
          end)
        end,
        desc = "Search in buffer",
      },
      -- Reopen the last picker with its query and cursor position intact
      { "<leader>fp", "<cmd>Telescope resume<cr>", desc = "Resume last picker" },
      { "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Keymaps" },
      { "<leader>fc", "<cmd>Telescope git_status<cr>", desc = "Changed files" },
    },
    config = function()
      -- The previewers capture nvim-treesitter at module load and never look
      -- again, so pull that module in first, under the compatibility shim —
      -- otherwise every preview raises instead of highlighting. See
      -- lua/config/tscompat.lua.
      require("config.tscompat").with(function() require("telescope.previewers.utils") end)

      local telescope = require("telescope")
      local actions = require("telescope.actions")

      telescope.setup({
        defaults = {
          path_display = { "smart" },
          -- Lua patterns, not globs: "*.o" would match a literal asterisk and
          -- silently never fire. Anchor extensions with %. and $.
          file_ignore_patterns = {
            "^%.git/", "/%.git/",
            "node_modules/", "__pycache__/", "%.venv/",
            "%.o$", "%.out$",
          },
          mappings = {
            i = {
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
              ["<Esc>"] = actions.close,
            },
          },
        },
        pickers = {
          find_files = { hidden = true },
        },
      })

      pcall(telescope.load_extension, "fzf")
    end,
  },
}
