return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    -- <C-\> toggles; <leader>T is the discoverable alias. Not mapped alone in
    -- terminal mode (terminal_mappings below): there <C-\> is the prefix of
    -- <C-\><C-n> and the window moves, so a terminal hides with <C-\><C-\>.
    keys = {
      { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
      { "<leader>T", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
    },
    config = function()
      require("toggleterm").setup({
        size = function(term)
          if term.direction == "horizontal" then
            return 18
          elseif term.direction == "vertical" then
            return math.floor(vim.o.columns * 0.4)
          end
        end,
        open_mapping      = [[<C-\>]],
        insert_mappings   = false,
        terminal_mappings = false,
        direction     = "horizontal",
        shade_terminals = true,
        persist_size  = true,
        persist_mode  = true,
        close_on_exit = true,
        shell         = vim.o.shell,
        on_create = function(term)
          vim.keymap.set("t", "<C-\\><C-\\>", "<cmd>ToggleTerm<cr>",
            { buffer = term.bufnr, desc = "Hide terminal" })
        end,
      })
      -- Terminal-mode keymaps are global (TermOpen in lua/config/autocmds.lua)
      -- so the run split, Claude and the debug console get them too.
    end,
  },
}
