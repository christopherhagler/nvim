return {
  -- Full Git commands
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "G", "Gdiffsplit", "Gvdiffsplit" },
    keys = {
      { "<leader>gs", "<cmd>Git<cr>",         desc = "Git status" },
      { "<leader>gc", "<cmd>Git commit<cr>",  desc = "Git commit" },
      { "<leader>gp", "<cmd>Git push<cr>",    desc = "Git push" },
      { "<leader>gl", "<cmd>Git log<cr>",     desc = "Git log" },
      { "<leader>gd", "<cmd>Gdiffsplit<cr>",  desc = "Git diff" },
      { "<leader>gb", "<cmd>Git blame<cr>",   desc = "Git blame" },
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
          local gs = require("gitsigns")
          local map = function(mode, keys, func, desc)
            vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = "Git: " .. desc })
          end

          -- Navigate hunks (falls back to built-in ]c / [c in diff mode)
          map("n", "]c", function()
            if vim.wo.diff then vim.cmd.normal({ "]c", bang = true }) else gs.nav_hunk("next") end
          end, "Next hunk")
          map("n", "[c", function()
            if vim.wo.diff then vim.cmd.normal({ "[c", bang = true }) else gs.nav_hunk("prev") end
          end, "Prev hunk")

          -- Stage / reset. stage_hunk toggles: run it on a staged hunk to
          -- unstage it (gitsigns deprecated undo_stage_hunk in favour of this),
          -- so there is no separate "undo stage" mapping.
          map("n", "<leader>hs", gs.stage_hunk,  "Stage/unstage hunk")
          map("n", "<leader>hr", gs.reset_hunk,  "Reset hunk")
          map("v", "<leader>hs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage/unstage hunk")
          map("v", "<leader>hr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset hunk")
          map("n", "<leader>hS", gs.stage_buffer,    "Stage buffer")
          map("n", "<leader>hR", gs.reset_buffer,    "Reset buffer")
          map("n", "<leader>hp", gs.preview_hunk,    "Preview hunk")
          map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
          map("n", "<leader>hd", gs.diffthis, "Diff this")
        end,
      })
    end,
  },
}
