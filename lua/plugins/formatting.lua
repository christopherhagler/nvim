return {
  -- Formatter: clangd handles C/C++ via LSP (lsp_fallback), explicit formatters for everything else
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          -- C/C++ intentionally omitted: clangd (LSP) formats via lsp_fallback
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
        format_on_save = {
          timeout_ms = 500,
          lsp_fallback = true,
        },
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
        "black", "isort", "prettier", "stylua", "shfmt",
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
