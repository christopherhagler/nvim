return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
    config = function()
      local lint = require("lint")

      -- C/C++ diagnostics come from clangd; no separate linter needed
      lint.linters_by_ft = {
        python          = { "flake8" },
        javascript      = { "eslint_d" },
        typescript      = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        typescriptreact = { "eslint_d" },
        sh              = { "shellcheck" },
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
