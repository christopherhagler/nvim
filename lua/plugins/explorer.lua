return {
  -- File explorer (replaces NERDTree)
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>n", "<cmd>NvimTreeToggle<cr>", desc = "Toggle file explorer" },
      { "<leader>nf", "<cmd>NvimTreeFindFile<cr>", desc = "Reveal file in explorer" },
    },
    config = function()
      require("nvim-tree").setup({
        view = { width = 35 },
        renderer = {
          group_empty = true,
          icons = { show = { git = true, folder = true, file = true } },
        },
        filters = { dotfiles = false },
        git = { enable = true, ignore = false },
        actions = { open_file = { quit_on_open = false } },
      })
    end,
  },

  -- Symbols outline powered by LSP/treesitter (replaces Tagbar)
  {
    "stevearc/aerial.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<F8>", "<cmd>AerialToggle<cr>", desc = "Toggle symbols outline" },
    },
    config = function()
      require("aerial").setup({
        layout = { default_direction = "right", min_width = 30 },
        backends = { "lsp", "treesitter", "markdown" },
        show_guides = true,
        attach_mode = "window",
      })
    end,
  },
}
