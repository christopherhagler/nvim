return {
  -- Full Git commands
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "G", "Gstatus", "Gdiff", "Gcommit", "Gpush" },
    keys = {
      { "<leader>gs", "<cmd>Git<cr>",          desc = "Git status" },
      { "<leader>gc", "<cmd>Git commit<cr>",   desc = "Git commit" },
      { "<leader>gp", "<cmd>Git push<cr>",     desc = "Git push" },
      { "<leader>gl", "<cmd>Git log<cr>",      desc = "Git log" },
      { "<leader>gd", "<cmd>Gdiffsplit<cr>",   desc = "Git diff" },
      { "<leader>gb", "<cmd>Git blame<cr>",    desc = "Git blame" },
    },
  },

  -- Gutter signs + hunk actions
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        signs = {
          add          = { text = "│" },
          change       = { text = "│" },
          delete       = { text = "_" },
          topdelete    = { text = "‾" },
          changedelete = { text = "~" },
          untracked    = { text = "┆" },
        },
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local map = function(mode, keys, func, desc)
            vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = "Git: " .. desc })
          end

          -- Navigate hunks
          map("n", "]c", function()
            if vim.wo.diff then return "]c" end
            vim.schedule(gs.next_hunk)
            return "<Ignore>"
          end, "Next hunk")
          map("n", "[c", function()
            if vim.wo.diff then return "[c" end
            vim.schedule(gs.prev_hunk)
            return "<Ignore>"
          end, "Prev hunk")

          -- Stage / reset
          map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
          map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
          map("v", "<leader>hs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage hunk")
          map("v", "<leader>hr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset hunk")
          map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
          map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage")
          map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")
          map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
          map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
          map("n", "<leader>hd", gs.diffthis, "Diff this")
        end,
      })
    end,
  },
}
