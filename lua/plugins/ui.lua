return {
  -- Colorscheme
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function()
      require("tokyonight").setup({
        style = "night",       -- night | storm | moon | day
        light_style = "day",
        transparent = false,
        terminal_colors = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = true },
          functions = {},
          variables = {},
          sidebars = "dark",
          floats = "dark",
        },
        sidebars = { "qf", "help", "terminal", "nvim-tree" },
        lualine_bold = true,
      })
      vim.cmd.colorscheme("tokyonight")
    end,
  },

  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          icons_enabled = true,
          theme = "tokyonight",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          globalstatus = true,
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        refresh = { statusline = 1000 },
      })
    end,
  },

  -- Command line popup + better messages UI
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    config = function()
      require("notify").setup({
        background_colour = "#000000",
        timeout = 3000,
        max_width = 60,
        render = "compact",
        stages = "fade",
      })

      require("noice").setup({
        cmdline = {
          enabled = true,
          view = "cmdline_popup",
          format = {
            cmdline  = { icon = " " },
            search_down = { icon = "  " },
            search_up   = { icon = "  " },
            filter   = { icon = " " },
            lua      = { icon = " " },
            help     = { icon = " " },
          },
        },
        messages = { enabled = true },
        popupmenu = { enabled = true, backend = "nui" },
        notify = { enabled = true, view = "notify" },
        lsp = {
          -- Let our own lsp handlers manage hover and signature
          hover = { enabled = false },
          signature = { enabled = false },
          progress = { enabled = true },
          message = { enabled = true },
        },
        presets = {
          bottom_search = false,      -- popup search box
          command_palette = true,     -- tall cmdline with autocomplete
          long_message_to_split = true,
          inc_rename = true,
        },
      })
    end,
  },

  -- Keybinding hints
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      local wk = require("which-key")
      wk.setup({})
      wk.add({
        { "<leader>f", group = "Find" },
        { "<leader>l", group = "LSP" },
        { "<leader>d", group = "Debug" },
        { "<leader>g", group = "Git" },
        { "<leader>h", group = "Hunks" },
        { "<leader>x", group = "Diagnostics" },
        { "<leader>q", group = "Session" },
      })
    end,
  },

  -- Icons
  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- Indent guides
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      indent = { char = "│" },
      scope = { enabled = true },
    },
  },

  -- TODO/FIXME/HACK highlights
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },

  -- Project-wide diagnostics panel
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",                        desc = "Project diagnostics" },
      { "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",           desc = "Buffer diagnostics" },
      { "<leader>xs", "<cmd>Trouble symbols toggle<cr>",                            desc = "Symbols" },
      { "<leader>xl", "<cmd>Trouble loclist toggle<cr>",                            desc = "Location list" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>",                             desc = "Quickfix list" },
    },
    opts = { use_diagnostic_signs = true },
  },
}
