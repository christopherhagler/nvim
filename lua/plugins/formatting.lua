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

      -- Python: ruff by default. It is already running as the lint server, it
      -- reads the same [tool.ruff] config, and it formats and sorts imports in
      -- one native process where black + isort are two Python interpreter
      -- start-ups per save. Its output is black-compatible, but it does not
      -- read [tool.black] or [tool.isort] — so a project configured for those
      -- tools keeps getting them, the way a project .clang-format wins below.
      local function python_formatters(bufnr)
        local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
        local pyproject = vim.fs.find("pyproject.toml", { upward = true, path = dir })[1]
        local legacy = vim.fs.find({ ".isort.cfg" }, { upward = true, path = dir })[1] ~= nil
        if pyproject and not legacy then
          local ok, lines = pcall(vim.fn.readfile, pyproject)
          local text = ok and table.concat(lines, "\n") or ""
          legacy = text:find("%[tool%.black%]") ~= nil or text:find("%[tool%.isort%]") ~= nil
        end
        if legacy then return { "isort", "black" } end
        return { "ruff_organize_imports", "ruff_format" }
      end

      require("conform").setup({
        formatters = {
          -- shfmt indents with hard tabs unless told otherwise; match the
          -- 2-space rule in lua/config/indent.lua. -ci indents switch cases.
          shfmt = { prepend_args = { "-i", "2", "-ci" } },
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
          cuda       = { "clang_format" },
          cmake      = { "cmake_format" },
          python     = python_formatters,
          -- matlab: no entry on purpose. <leader>lf falls back to matlab_ls,
          -- which formats through MATLAB's own indenter (needs MATLAB).
          javascript = { "prettier" },
          typescript = { "prettier" },
          javascriptreact = { "prettier" },
          typescriptreact = { "prettier" },
          html  = { "prettier" },
          css   = { "prettier" },
          scss  = { "prettier" },
          json  = { "prettier" },
          yaml  = { "prettier" },
          markdown = { "prettier" },
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
    event = "VeryLazy",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      -- List: lua/config/tools.lua (LSP servers live in lua/config/servers.lua)
      ensure_installed = require("config.tools"),
      auto_update = false,
      -- Skip the startup install check on air-gapped systems (the offline RPM
      -- sets NVIM_OFFLINE via /etc/profile.d; everything ships pre-installed)
      run_on_start = not vim.env.NVIM_OFFLINE,
    },
  },
}
