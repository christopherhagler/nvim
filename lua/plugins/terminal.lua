return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    -- <C-\> toggles; <leader>tt is the discoverable alias (tests own the rest
    -- of <leader>t). Inside a toggleterm terminal <C-\> also toggles
    -- (open_mapping below), so it can be dismissed without leaving terminal
    -- mode first. That mapping is buffer-local on purpose: everywhere else
    -- <C-\> must stay the start of <C-\><C-n>.
    keys = {
      { "<C-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
      { "<leader>tt", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
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
        terminal_mappings = true,
        direction     = "horizontal",
        shade_terminals = true,
        persist_size  = true,
        persist_mode  = true,
        close_on_exit = true,
        shell         = vim.o.shell,
      })
      -- Terminal-mode keymaps are global (TermOpen in lua/config/autocmds.lua)
      -- so the run split, Claude and the debug console get them too.
    end,
  },
}
