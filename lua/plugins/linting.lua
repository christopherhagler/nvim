return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
    config = function()
      local lint = require("lint")

      -- Only linters that no language server already covers belong here.
      -- C/C++ diagnostics come from clangd, shell from bashls (which spawns
      -- shellcheck itself), Python from the ruff server, and JS/TS from the
      -- eslint server — all with quick-fix code actions, which nvim-lint cannot
      -- offer. Re-running them here would just duplicate.
      --
      -- (JS/TS used to run eslint_d here. It moved to the eslint language
      -- server in lua/config/servers.lua: same engine, same project config,
      -- but "fix all auto-fixable problems" becomes a code action on <leader>a
      -- instead of a diagnostic you have to fix by hand.)
      --
      -- That leaves the two filetypes with no server at all.
      lint.linters_by_ft = {
        markdown = { "markdownlint" },
        yaml     = { "yamllint" },
      }

      -- Both of these ship a default config that fights the formatter, and both
      -- do it loudly. Out of the box, markdownlint puts 58 line-length errors on
      -- this repo's own README, and yamllint puts 5 on its own workflow file —
      -- line length, missing `---`, `on:` read as the boolean `on`. prettier
      -- owns the layout of both filetypes (lua/plugins/formatting.lua) and will
      -- not rewrap prose, so every one of those is a complaint about something
      -- nothing in this config will ever fix. Real markdown/YAML problems —
      -- unlabelled code fences, duplicate keys, bad indentation, syntax errors —
      -- still report; that is the half worth keeping.
      --
      -- A project that ships its own config outranks all of this, the same way
      -- a project .clang-format outranks the built-in C/C++ style. The path is
      -- passed explicitly rather than left to each tool's own discovery, which
      -- searches the process cwd and so misses the config whenever Neovim was
      -- started from somewhere other than the project root.
      local function project_config(names)
        return vim.fs.find(names, { upward = true, path = vim.fn.expand("%:p:h") })[1]
      end

      -- Argument lists may contain functions; nvim-lint evaluates them at lint
      -- time, which is what makes this per-buffer rather than fixed at startup.
      -- Inserted first because yamllint's own arg list ends in the `-` that
      -- means "read stdin", which has to stay last.
      table.insert(lint.linters.yamllint.args, 1, function()
        local cfg = project_config({ ".yamllint", ".yamllint.yaml", ".yamllint.yml" })
        if cfg then return "--config-file=" .. cfg end
        return "--config-data={extends: default, rules: {"
          .. "line-length: disable, "        -- prettier owns wrapping
          .. "document-start: disable, "     -- prettier never emits the leading ---
          .. "truthy: {check-keys: false}, " -- GitHub Actions' `on:` is not a boolean
          .. "comments: {min-spaces-from-content: 1}}}"
      end)

      -- The --opt=value form matters here: --disable is variadic, so the
      -- space-separated form would need a trailing `--` to stop it swallowing
      -- whatever argument came next.
      table.insert(lint.linters.markdownlint.args, function()
        local cfg = project_config({
          ".markdownlint.json", ".markdownlint.jsonc", ".markdownlint.yaml", ".markdownlint.yml",
        })
        return cfg and ("--config=" .. cfg) or "--disable=MD013" -- MD013 = line length
      end)

      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("nvim_lint", { clear = true }),
        callback = function() lint.try_lint() end,
      })

      -- Lint the buffer that triggered the initial plugin load
      lint.try_lint()
    end,
  },
}
