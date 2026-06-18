return {
  -- Colorscheme
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function()
      require("tokyonight").setup({
        style = "moon",
        light_style = "day",
        transparent = false,
        terminal_colors = true,
        dim_inactive = true,
        lualine_bold = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = true },
          functions = { bold = true },
          variables = {},
          sidebars = "dark",
          floats = "dark",
        },
        sidebars = { "qf", "help", "terminal", "neo-tree", "nvim-tree" },
        on_highlights = function(hl, c)
          -- Visible matching brackets
          hl.MatchParen = { fg = c.orange, bold = true, underline = true }
          -- Stronger indent scope line
          hl.IblScope = { fg = c.blue2 }
          -- Popup menu selection stands out more
          hl.PmenuSel = { bg = c.blue, fg = c.bg }
          -- Float borders match the theme
          hl.FloatBorder = { fg = c.blue1, bg = c.bg_float }
        end,
      })
      vim.cmd.colorscheme("tokyonight")
    end,
  },

  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local function lsp_client()
        local clients = vim.lsp.get_clients({ bufnr = 0 })
        if #clients == 0 then return "" end
        local names = {}
        for _, c in ipairs(clients) do
          if c.name ~= "null-ls" and c.name ~= "copilot" then
            table.insert(names, c.name)
          end
        end
        return #names > 0 and ("  " .. table.concat(names, ", ")) or ""
      end

      require("lualine").setup({
        options = {
          icons_enabled = true,
          theme = "tokyonight",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          globalstatus = true,
          disabled_filetypes = { statusline = { "neo-tree", "nvim-tree" } },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1, symbols = { modified = " ●", readonly = " ", unnamed = "[No Name]" } } },
          lualine_x = { lsp_client, "encoding", "fileformat", "filetype" },
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
        { "<leader>d", group = "Debug" },
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Git" },
        { "<leader>h", group = "Hunks" },
        { "<leader>l", group = "LSP" },
        { "<leader>q", group = "Session" },
        { "<leader>r", group = "Refactor" },
        { "<leader>x", group = "Diagnostics" },
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
