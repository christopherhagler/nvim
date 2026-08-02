return {
  -- Colorscheme
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    config = function()
      -- gruvbox uses one palette for both backgrounds and just flips the roles,
      -- so pick the handful of colors we reference ourselves off 'background'.
      local dark = vim.o.background ~= "light"
      local bg_normal = dark and "#282828" or "#fbf1c7" -- bg0
      local bg_sunken = dark and "#1d2021" or "#ebdbb2" -- one step away from bg0
      local blue       = dark and "#83a598" or "#076678"
      local orange     = dark and "#fe8019" or "#af3a03"

      require("gruvbox").setup({
        contrast = "",
        transparent_mode = false,
        terminal_colors = true,
        dim_inactive = true,
        bold = true,
        italic = {
          comments = true,
          strings = false,
          operators = false,
          emphasis = true,
          folds = true,
        },
        overrides = {
          -- Visible matching brackets
          MatchParen = { fg = orange, bold = true, underline = true },
          -- Stronger indent scope line
          IblScope = { fg = blue },
          -- Popup menu selection stands out more
          PmenuSel = { bg = blue, fg = bg_normal, bold = true },
          -- Floats and sidebars sit a shade off the normal background
          NormalFloat = { bg = bg_sunken },
          FloatBorder = { fg = blue, bg = bg_sunken },
          NormalSidebar = { bg = bg_sunken },
          NvimTreeNormal = { bg = bg_sunken },
          NvimTreeNormalNC = { bg = bg_sunken },
          NvimTreeEndOfBuffer = { fg = bg_sunken, bg = bg_sunken },
          NvimTreeWinSeparator = { fg = bg_sunken, bg = bg_sunken },
        },
      })
      vim.cmd.colorscheme("gruvbox")

      -- gruvbox has no per-group italic/bold switches, so layer those on top of
      -- whatever colors the scheme resolved to. Treesitter groups link straight
      -- to color groups rather than to Keyword/Function, so name both.
      local function add(group, attrs)
        local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
        vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", hl, attrs))
      end

      local function restyle()
        for _, g in ipairs({ "Keyword", "Statement", "Conditional", "Repeat", "Exception", "@keyword" }) do
          add(g, { italic = true })
        end
        for _, g in ipairs({ "Function", "@function", "@function.call", "@function.method" }) do
          add(g, { bold = true })
        end
      end

      local group = vim.api.nvim_create_augroup("gruvbox_tweaks", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", { group = group, pattern = "gruvbox", callback = restyle })
      restyle()

      -- Sunken background for sidebar-ish windows
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "qf", "help" },
        callback = function()
          vim.wo.winhighlight = "Normal:NormalSidebar,NormalNC:NormalSidebar"
        end,
      })
      vim.api.nvim_create_autocmd("TermOpen", {
        group = group,
        callback = function()
          vim.wo.winhighlight = "Normal:NormalSidebar,NormalNC:NormalSidebar"
        end,
      })
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
          theme = "gruvbox",
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
        { "<leader>c", group = "Claude" },
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
