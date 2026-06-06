return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = { { "<leader>t", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" } },
    config = function()
      require("toggleterm").setup({
        size = function(term)
          if term.direction == "horizontal" then
            return 18
          elseif term.direction == "vertical" then
            return math.floor(vim.o.columns * 0.4)
          end
        end,
        direction     = "horizontal",
        shade_terminals = true,
        persist_size  = true,
        persist_mode  = true,
        close_on_exit = true,
        shell         = vim.o.shell,
      })

      -- Terminal-mode keymaps: applied per-terminal buffer on open
      local function set_terminal_keymaps()
        local opts = { buffer = 0 }
        vim.keymap.set("t", "<Esc>",   "<C-\\><C-n>",       opts)
        vim.keymap.set("t", "<C-h>",   "<C-\\><C-n><C-w>h", opts)
        vim.keymap.set("t", "<C-j>",   "<C-\\><C-n><C-w>j", opts)
        vim.keymap.set("t", "<C-k>",   "<C-\\><C-n><C-w>k", opts)
        vim.keymap.set("t", "<C-l>",   "<C-\\><C-n><C-w>l", opts)
      end

      vim.api.nvim_create_autocmd("TermOpen", {
        pattern  = "term://*toggleterm#*",
        callback = set_terminal_keymaps,
      })
    end,
  },
}
