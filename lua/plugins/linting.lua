return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
    config = function()
      local lint = require("lint")

      -- C/C++ diagnostics come from clangd; no separate linter needed.
      -- Shell diagnostics come from bashls (runs shellcheck itself) and
      -- Python from the auto-enabled ruff LSP server — both with quick-fix
      -- code actions; running those linters here again would duplicate.
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
