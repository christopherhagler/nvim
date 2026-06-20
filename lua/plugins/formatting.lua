return {
  -- Formatter: conform runs an explicit formatter per filetype (clang-format for C/C++)
  {
    "stevearc/conform.nvim",
    cmd = "ConformInfo",
    config = function()
      -- C/C++ default style lives here (not in a ~/.clang-format): K&R braces,
      -- 4-space indent, 120-column limit. If a project provides its own
      -- .clang-format, that file is used instead (--style=file).
      local clang_style =
        "{BasedOnStyle: LLVM, IndentWidth: 4, TabWidth: 4, UseTab: Never, "
        .. "ColumnLimit: 120, BreakBeforeBraces: Attach, "
        .. "AllowShortFunctionsOnASingleLine: None, PointerAlignment: Right, SortIncludes: true}"

      require("conform").setup({
        formatters = {
          clang_format = {
            prepend_args = function(_, ctx)
              local project = vim.fs.find({ ".clang-format", "_clang-format" }, {
                upward = true,
                path = ctx.dirname,
              })[1]
              return { "--style=" .. (project and "file" or clang_style) }
            end,
          },
        },
        formatters_by_ft = {
          c          = { "clang_format" },
          cpp        = { "clang_format" },
          python     = { "black", "isort" },
          javascript = { "prettier" },
          typescript = { "prettier" },
          javascriptreact = { "prettier" },
          typescriptreact = { "prettier" },
          html  = { "prettier" },
          css   = { "prettier" },
          scss  = { "prettier" },
          json  = { "prettier" },
          yaml  = { "prettier" },
          lua   = { "stylua" },
          sh    = { "shfmt" },
        },
        -- Format manually with <leader>lf (no format-on-save)
      })
    end,
  },

  -- Auto-install formatters and linters via Mason
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        -- Formatters
        "black", "isort", "prettier", "stylua", "shfmt", "clang-format",
        -- Linters
        "flake8", "eslint_d", "shellcheck",
        -- Debug adapters
        "codelldb", "debugpy", "js-debug-adapter",
      },
      auto_update = false,
      run_on_start = true,
    },
  },
}
