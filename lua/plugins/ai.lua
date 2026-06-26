return {
  -- Claude Code: connects the local `claude` CLI to Neovim using the same
  -- WebSocket/MCP protocol as the official VS Code extension. Claude becomes
  -- editor-aware — sees your selection, open files, and diagnostics, and
  -- proposes edits as native diffs you accept/reject.
  {
    "coder/claudecode.nvim",
    cmd = {
      "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeSelectModel",
      "ClaudeCodeAdd", "ClaudeCodeSend",
      "ClaudeCodeDiffAccept", "ClaudeCodeDiffDeny",
    },
    keys = {
      { "<leader>cc", "<cmd>ClaudeCode<cr>",            desc = "Toggle Claude" },
      { "<leader>cf", "<cmd>ClaudeCodeFocus<cr>",       desc = "Focus Claude" },
      { "<leader>cm", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select model" },
      { "<leader>cb", "<cmd>ClaudeCodeAdd %<cr>",       desc = "Add current file to context" },
      { "<leader>cs", "<cmd>ClaudeCodeSend<cr>",        mode = "v", desc = "Send selection to Claude" },
      -- Accept / reject a proposed diff
      { "<leader>ca", "<cmd>ClaudeCodeDiffAccept<cr>",  desc = "Accept Claude diff" },
      { "<leader>cr", "<cmd>ClaudeCodeDiffDeny<cr>",    desc = "Reject Claude diff" },
    },
    opts = {
      -- Use Neovim's built-in terminal instead of pulling in folke/snacks.nvim;
      -- general-purpose terminals stay with toggleterm (<leader>t).
      terminal = { provider = "native" },
    },
  },
}
