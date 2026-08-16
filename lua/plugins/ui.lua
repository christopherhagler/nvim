return {
  -- Colorscheme
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function()
      require("tokyonight").setup({
        style = "night",
        light_style = "day",
        transparent = false,
        terminal_colors = true,
        -- Dimming the inactive split washes out half the screen and forces the
        -- eye to re-adapt on every window jump. Off is calmer with splits open.
        dim_inactive = false,
        lualine_bold = true,
        styles = {
          comments = { italic = true },
          keywords = { italic = true },
          functions = { bold = true },
          variables = {},
          sidebars = "dark",
          floats = "dark",
        },
        sidebars = { "qf", "help", "terminal", "nvim-tree" },
        -- Eye-comfort pass. Stock night spans a very wide contrast range: body
        -- text is 10.6:1 against the background while comments are 2.9:1, so
        -- the eye keeps re-adapting. These values compress that to ~4.3:1 –
        -- 8.3:1 — comments become legible, bright text stops glaring, and the
        -- hottest accents come down to meet everything else. Hues are
        -- untouched, so it still reads as tokyonight.
        --
        -- All ratios below are against night's bg (#1a1b26). Switching back to
        -- storm (#24283b) lifts every ratio here by roughly 15%, so the values
        -- want re-tuning if you change 'style'.
        on_colors = function(c)
          c.fg      = "#aab4d2" -- was #c0caf5 — 10.6:1 -> 8.3:1
          c.fg_dark = "#98a0c2"
          c.comment = "#757ea6" -- was #565f89 — 2.9:1 -> 4.3:1, the big one
          c.dark3   = "#646d98" -- line numbers, ignored files
          c.dark5   = "#7e87b0"

          -- The four accents that read hottest on a dark background.
          c.cyan   = "#6cb4dc" -- 10.0:1 -> 7.5:1
          c.green  = "#8cb75f" -- 9.4:1 -> 7.4:1
          c.yellow = "#c69a5e" -- 8.5:1 -> 6.7:1
          c.orange = "#dc8a58" -- 8.4:1 -> 6.4:1

          -- on_colors runs after tokyonight derives these, so re-point the ones
          -- that were copied from values we just changed.
          c.fg_float   = c.fg
          c.fg_sidebar = c.fg_dark
          c.warning    = c.yellow
          c.git.ignore = c.dark3
          c.terminal.white        = c.fg_dark
          c.terminal.white_bright = c.fg
          c.terminal.green        = c.green
          c.terminal.yellow       = c.yellow
          c.terminal.cyan         = c.cyan
        end,
        on_highlights = function(hl, c)
          -- Stock LineNr is fg_gutter (1.5:1) — effectively invisible, and with
          -- relativenumber on you read it constantly. dark3 lands at 3.3:1:
          -- legible at a glance without competing with the code.
          hl.LineNr = { fg = c.dark3 }
          hl.LineNrAbove = { fg = c.dark3 }
          hl.LineNrBelow = { fg = c.dark3 }
          -- Visible matching brackets
          hl.MatchParen = { fg = c.orange, bold = true, underline = true }
          -- Stronger indent scope line
          hl.IblScope = { fg = c.blue2 }
          -- Popup menu selection: muted blue rather than a full-saturation bar,
          -- which flashes on every keystroke while completing.
          hl.PmenuSel = { bg = c.blue0, fg = c.fg, bold = true }
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
          disabled_filetypes = { statusline = { "nvim-tree" } },
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
        { "<leader>b", group = "Build/Run/CMake" },
        { "<leader>c", group = "Claude" },
        { "<leader>d", group = "Debug" },
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Git" },
        { "<leader>h", group = "Hunks" },
        { "<leader>l", group = "LSP" },
        { "<leader>q", group = "Session" },
        { "<leader>r", group = "Refactor/Replace" },
        { "<leader>s", group = "Swap (treesitter)" },
        { "<leader>T", group = "Test" },
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
