return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
    config = function()
      local lint = require("lint")

      -- Only linters that no language server already covers belong here.
      -- C/C++ diagnostics come from clangd, shell from bashls (which spawns
      -- shellcheck itself), and Python from the ruff server enabled in
      -- lua/config/servers.lua — all three with quick-fix code actions, which
      -- nvim-lint cannot offer. Re-running them here would just duplicate.
      lint.linters_by_ft = {
        javascript      = { "eslint_d" },
        typescript      = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        typescriptreact = { "eslint_d" },
      }

      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("nvim_lint", { clear = true }),
        callback = function() lint.try_lint() end,
      })

      -- Lint the buffer that triggered the initial plugin load
      lint.try_lint()
    end,
  },
}
